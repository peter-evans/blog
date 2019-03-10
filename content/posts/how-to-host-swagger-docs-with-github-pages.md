---
title: "How to Host Swagger Documentation With Github Pages"
date: 2018-05-02T15:23:13+09:00
author: Peter Evans
description: "How to host Swagger API documentation with GitHub Pages"
---

This article describes how use the [Swagger UI](https://github.com/swagger-api/swagger-ui) to dynamically generate beautiful documentation for your API and host it for free with GitHub Pages.

An example API specification can be seen hosted at [https://peter-evans.github.io/swagger-github-pages](https://peter-evans.github.io/swagger-github-pages/).

### Steps

1. Download the latest stable release of the Swagger UI [here](https://github.com/swagger-api/swagger-ui/releases).

2. Extract the contents and copy the "dist" directory to the root of your repository.

3. Move the file "index.html" from the directory "dist" to the root of your repository.
    ```
    mv dist/index.html .
    ```

4. Copy the YAML specification file for your API to the root of your repository.

5. Edit index.html and change the `url` property to reference your local YAML file. 
    ```javascript
        const ui = SwaggerUIBundle({
            url: "swagger.yaml",
        ...
    ```
    Then fix any references to files in the "dist" directory.
    ```html
    ...
    <link rel="stylesheet" type="text/css" href="dist/swagger-ui.css" >
    <link rel="icon" type="image/png" href="dist/favicon-32x32.png" sizes="32x32" />
    <link rel="icon" type="image/png" href="dist/favicon-16x16.png" sizes="16x16" />    
    ...
    <script src="dist/swagger-ui-bundle.js"> </script>
    <script src="dist/swagger-ui-standalone-preset.js"> </script>    
    ...
    ```
    
6. Go to the settings for your repository at `https://github.com/{github-username}/{repository-name}/settings` and enable GitHub Pages.

    ![Headers](/img/swagger-github-pages.png)
    
7. Browse to the Swagger documentation at `https://{github-username}.github.io/{repository-name}/`.

The sample code and API specification can be found at [https://github.com/peter-evans/swagger-github-pages](https://github.com/peter-evans/swagger-github-pages).
