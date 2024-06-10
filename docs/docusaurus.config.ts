import {
  duotoneLight,
  themes as prismThemes,
  vsLight
} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'MapLibre GL Flutter',
  tagline: 'Flutter MapLibre bindings for iOS, Android and Web',
  favicon: 'https://maplibre.org/favicon.ico',

  // Set the production url of your site here
  url: 'https://josxha.github.io',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/flutter-maplibre-gl/',

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: 'joshxa', // Usually your GitHub org/user name.
  projectName: 'flutter-maplibre-gl', // Usually your repo name.

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          editUrl:
            'https://github.com/josxha/flutter-maplibre-gl/tree/main/docs/',
        },
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    // Replace with your project's social card
    // image: 'img/maplibre-social-card.jpg',
    navbar: {
      title: 'MapLibre GL Flutter',
      logo: {
        alt: 'MapLibre Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: 'Getting Started',
        },
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: 'Docs',
        },
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: 'FAQ',
        },
        {
          type: 'docsVersionDropdown',
          position: 'right',
        },
        {
          href: "https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/maplibre_gl-library.html",
          position: 'right',
          label: 'API',
        },
        {
          href: "https://maplibre.org/flutter-maplibre-gl/demo/",
          position: 'right',
          label: 'Demo App',
        },
        {
          href: 'https://github.com/maplibre/flutter-maplibre-gl',
          position: 'right',
          label: 'GitHub',
        },
        {
          href: 'https://pub.dev/packages/maplibre_gl',
          position: 'right',
          label: 'pub.dev',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Documentation',
          items: [
            {
              label: 'Getting Started',
              to: '/docs/getting-started/add-dependency',
            },
            {
              label: 'Docs',
              to: '/docs/category/features',
            },
            {
              label: 'Frequent Questions',
              to: '/docs/category/faq',
            },
            {
              label: 'API Reference',
              href: 'https://pub.dev/documentation/maplibre_gl/latest/maplibre_gl/maplibre_gl-library.html',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'OpenStreetMap US Slack',
              href: 'https://slack.openstreetmap.us',
            },
            {
              label: 'StackOverflow',
              href: 'https://stackoverflow.com/questions/tagged/flutter-maplibre-gl',
            },
            {
              label: 'GitHub Discussions',
              href: 'https://github.com/maplibre/flutter-maplibre-gl/discussions',
            },
          ],
        },
        {
          title: 'Resources',
          items: [
            {
              label: 'GitHub',
              href: 'https://github.com/maplibre/flutter-maplibre-gl',
            },
            {
              label: 'pub.dev',
              href: 'https://pub.dev/packages/maplibre_gl',
            },
            {
              label: 'Demo App',
              href: 'https://maplibre.org/flutter-maplibre-gl/demo/',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} MapLibre contributors`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['dart', 'bash', 'gradle'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
