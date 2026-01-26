---
title: "Pagination: Supporting Both Cursor and Page-Based Strategies"
date: 2026-01-26T15:40:35Z
author: Peter Evans
description: "How to support both cursor-based and page-based pagination in a single API using a unified, type-aware cursor format"
keywords: ["pagination", "cursor-based pagination", "page-based pagination", "keyset pagination", "api design", "go", "golang"]
---

Pagination is one of those "solved problems" that keeps coming back to haunt us. Maybe you chose cursor-based pagination because it's more efficient for large datasets. Maybe your mobile team chose page-based pagination because users want to jump to "page 5." Now you need to support both, without breaking anyone!

This is pretty much the scenario I faced recently, and so I thought I'd share the approach I took to support multiple pagination strategies in a single API while maintaining backward compatibility.

### Pagination Strategy Tradeoffs

Let's start with why this problem exists. Cursor-based and page-based pagination solve different problems.

**Cursor-based pagination** (also called keyset pagination):
- Uses an opaque token pointing to a specific record
- Handles concurrent inserts/deletes gracefully
- Efficient for infinite scroll UIs
- O(1) database performance regardless of offset

**Page-based pagination**:
- Uses page numbers (page 1, page 2, etc.)
- Familiar UI pattern ("Showing page 3 of 10")
- Users can jump to arbitrary pages
- Suffers from offset performance issues on large datasets

The general advice tends to be _"just pick cursor-based, it's better."_ But these tradeoffs show why that's not always straightforward. Your API might have been designed for infinite scroll on mobile (cursor-based), but then a dashboard team needs "page 3 of 10" for their UI. Or you inherited a page-based system and now need to scale it without breaking existing clients. Requirements evolve, and sometimes the right answer is to support both.

### A Unified Cursor Format

The foundation of this design is that **the cursor is just an opaque string to clients**. They shouldn't parse it—they just pass it back. This means we can encode *any* pagination state inside it.

```go
// Cursor represents pagination state that supports both strategies
type Cursor struct {
    ID   string `json:"id,omitempty"`   // For cursor-based pagination
    Page int64  `json:"page,omitempty"` // For page-based pagination
}
```

Encoded as base64 JSON, a cursor-based cursor looks like:
```
eyJpZCI6IjEyMzQ1In0=  →  {"id":"12345"}
```

And a page-based cursor:
```
eyJwYWdlIjoyfQ==  →  {"page":2}
```

Clients see an opaque string, but the server knows exactly what to do.

### Decoding with Type Detection

When a request comes in, we need to figure out what kind of pagination the client is using:

```go
type PaginationType int

const (
    PaginationTypeCursor PaginationType = iota
    PaginationTypePage
)

type DecodedCursor struct {
    Type PaginationType
    ID   string // For cursor-based
    Page int64  // For page-based
}

func DecodeCursor(cursor string) DecodedCursor {
    if cursor == "" {
        // Empty cursor = first page, default to cursor-based
        return DecodedCursor{Type: PaginationTypeCursor}
    }

    dec, err := base64.StdEncoding.DecodeString(cursor)
    if err != nil {
        return DecodedCursor{Type: PaginationTypeCursor}
    }

    var cur Cursor
    if err := json.Unmarshal(dec, &cur); err != nil {
        return DecodedCursor{Type: PaginationTypeCursor}
    }

    // Determine type based on which field is populated
    if cur.Page > 0 {
        return DecodedCursor{
            Type: PaginationTypePage,
            Page: cur.Page,
        }
    }
    return DecodedCursor{
        Type: PaginationTypeCursor,
        ID:   cur.ID,
    }
}
```

If we can't decode the cursor, we assume cursor-based pagination beginning at the start. It's generally preferable to degrade gracefully in this way than to throw an error.

## Querying the Database

Here's a basic example of how we go about translating the decoded cursor into actual database queries.

```go
func (s *Store) ListItems(ctx context.Context, cursor DecodedCursor, limit int) ([]Item, error) {
    switch cursor.Type {
    case PaginationTypeCursor:
        return s.listByCursor(ctx, cursor.ID, limit)
    case PaginationTypePage:
        return s.listByPage(ctx, cursor.Page, limit)
    default:
        return s.listByCursor(ctx, "", limit)
    }
}

func (s *Store) listByCursor(ctx context.Context, afterID string, limit int) ([]Item, error) {
    query := `
        SELECT id, name, created_at 
        FROM items 
        WHERE ($1 = '' OR id > $1)
        ORDER BY id ASC
        LIMIT $2
    `
    return s.query(ctx, query, afterID, limit)
}

func (s *Store) listByPage(ctx context.Context, page int64, limit int) ([]Item, error) {
    offset := (page - 1) * int64(limit)
    query := `
        SELECT id, name, created_at 
        FROM items 
        ORDER BY id ASC
        LIMIT $1 OFFSET $2
    `
    return s.query(ctx, query, limit, offset)
}
```

You'll notice cursor-based uses a `WHERE id > $1` condition (efficient), while page-based uses `OFFSET` (less efficient for large offsets, but sometimes necessary for the UX).

### Preserving Pagination Type Through Response Cycles

Something to watch out for is that the next cursor should use the same pagination type as the current request. If a client starts with page-based pagination, they'll expect to stay in page-based pagination!

```go
func EncodeNextCursor(currentPage DecodedCursor, lastID string) string {
    switch currentPage.Type {
    case PaginationTypePage:
        // Client is using pages, give them the next page
        return EncodePageCursor(currentPage.Page + 1)
    default:
        // Client is using cursors, give them the next cursor
        return EncodeCursorID(lastID)
    }
}

func EncodePageCursor(page int64) string {
    b, _ := json.Marshal(Cursor{Page: page})
    return base64.StdEncoding.EncodeToString(b)
}

func EncodeCursorID(id string) string {
    b, _ := json.Marshal(Cursor{ID: id})
    return base64.StdEncoding.EncodeToString(b)
}
```

### Performance Considerations

It's worth being upfront with API consumers about the tradeoffs:

| Aspect | Cursor-Based | Page-Based |
|--------|--------------|------------|
| First page | Fast | Fast |
| Page 1000 | Fast | Slow (OFFSET scan) |
| Concurrent writes | Consistent | May skip/duplicate |
| Jump to arbitrary page | Not supported | Supported |

If you're supporting page-based for UX reasons but have large datasets, you may want to consider:
- Capping the maximum page number
- Suggesting cursor-based for programmatic access
- Using estimated counts instead of exact counts for "page X of Y"

### Final Thoughts

Supporting multiple pagination strategies doesn't have to mean duplicating your API. With a type-aware cursor format, I was able to:

1. **Encode pagination state in opaque cursors** — clients don't need to understand the format
2. **Detect pagination type on decode** — the cursor tells us how to query
3. **Preserve type through the request cycle** — next cursor matches current strategy
4. **Degrade gracefully** — unknown/malformed cursors reset to page 1, cursor-based

This allowed the API I was working on to serve different clients with different needs through a single endpoint, without breaking changes.
