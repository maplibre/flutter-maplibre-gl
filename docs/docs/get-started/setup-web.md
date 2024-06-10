---
sidebar_position: 4
---

# Setup Web

## General setup

Include the following JavaScript and CSS files in the `<head>` of
your `web/index.html` file:

```html
<!DOCTYPE html>
<html>
<head>
    <!-- other html -->

    <!-- MapLibre -->
    <script src='https://unpkg.com/maplibre-gl@^4.3/dist/maplibre-gl.js'></script>
    <link href='https://unpkg.com/maplibre-gl@^4.3/dist/maplibre-gl.css'
          rel='stylesheet'/>
</head>
</html>
```

`^4.3` ensures that your app will always use the latest version of
[maplibre-gl-js](https://github.com/maplibre/maplibre-gl-js) v4 but not suddenly
use an incompatible version.