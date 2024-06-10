# Documentation

The documentation website is built using [Docusaurus](https://docusaurus.io/), 
a static website generator.
See the hosted documentation at [TODO insert url]()

## Run locally

To run the website locally, you need to have Node.js and yarn installed. 
You can Node.js from [here](https://nodejs.org/) and install yarn by running 
`npm install -g yarn`.

Run the following commands to fetch the dependencies:

```bash
yarn
```

Then, run the following command to start the development server:

```bash
$ yarn start
```

This command starts a local development server. Most changes are reflected live 
without having to restart the server.

### Build

```
$ yarn build
```

This command generates static content into the `build` directory and can be served using any static contents hosting service.

### Deployment

The website is deployed automatically to GitHub Pages via CI.