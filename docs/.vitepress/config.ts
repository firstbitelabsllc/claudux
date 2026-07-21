import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'claudux',
  description: 'Generate VitePress docs from your codebase via Claude or Codex, preview them locally, ship them.',
  base: process.env.DOCS_BASE || '/',
  
  // Ignore localhost links during static builds
  ignoreDeadLinks: [
    /^https?:\/\/localhost/
  ],
  
  head: [
    ['meta', { name: 'theme-color', content: '#5f67ee' }],
    ['meta', { property: 'og:type', content: 'website' }],
    ['meta', { property: 'og:locale', content: 'en' }],
    ['meta', { property: 'og:title', content: 'claudux — VitePress docs generated from your codebase' }],
    ['meta', { property: 'og:site_name', content: 'claudux Docs' }],
    ['meta', { property: 'og:url', content: '/' }],
  ],

  cleanUrls: true,

  markdown: {
    theme: { light: 'github-light', dark: 'github-dark' },
    lineNumbers: true
  },

  themeConfig: {
    siteTitle: 'claudux',

    nav: [
      { text: 'Guide', link: '/guide/', activeMatch: '/guide/' },
      { text: 'Features', link: '/features/', activeMatch: '/features/' },
      { text: 'Technical', link: '/technical/', activeMatch: '/technical/' },
      { text: 'API', link: '/api/', activeMatch: '/api/' }
    ],

    sidebar: {
      '/': [
        {
          text: '🚀 Getting Started',
          collapsed: false,
          items: [
            { text: 'Overview', link: '/guide/' },
            { text: 'Installation', link: '/guide/installation' },
            { text: 'Commands', link: '/guide/commands' },
            { text: 'Configuration', link: '/guide/configuration' }
          ]
        },
        {
          text: '✨ Features',
          collapsed: false,
          items: [
            { text: 'Overview', link: '/features/' },
            { text: 'Two-Phase Generation', link: '/features/two-phase-generation' },
            { text: 'Smart Cleanup', link: '/features/smart-cleanup' },
            { text: 'Content Protection', link: '/features/content-protection' }
          ]
        },
        {
          text: '🔧 Technical',
          collapsed: true,
          items: [
            { text: 'Architecture', link: '/technical/' },
            { text: 'Templates', link: '/technical/templates' },
            { text: 'Deterministic Generation', link: '/technical/deterministic-generation' }
          ]
        },
        {
          text: '📚 Reference',
          collapsed: true,
          items: [
            { text: 'Examples', link: '/examples/' },
            { text: 'API Reference', link: '/api/' },
            { text: 'Troubleshooting', link: '/troubleshooting' }
          ]
        }
      ],
      '/guide/': [
        {
          text: '🚀 Getting Started',
          collapsed: false,
          items: [
            { text: 'Overview', link: '/guide/' },
            { text: 'Installation', link: '/guide/installation' },
            { text: 'Commands', link: '/guide/commands' },
            { text: 'Configuration', link: '/guide/configuration' }
          ]
        }
      ],
      '/features/': [
        {
          text: '✨ Features',
          collapsed: false,
          items: [
            { text: 'Overview', link: '/features/' },
            { text: 'Two-Phase Generation', link: '/features/two-phase-generation' },
            { text: 'Smart Cleanup', link: '/features/smart-cleanup' },
            { text: 'Content Protection', link: '/features/content-protection' }
          ]
        }
      ],
      '/technical/': [
        {
          text: '🔧 Technical',
          collapsed: false,
          items: [
            { text: 'Architecture', link: '/technical/' },
            { text: 'Templates', link: '/technical/templates' },
            { text: 'Deterministic Generation', link: '/technical/deterministic-generation' }
          ]
        }
      ]
    },

    socialLinks: [
      { icon: 'github', link: 'https://github.com/firstbitelabsllc/claudux' }
    ],

    footer: {
      message: 'Generated with claudux',
      copyright: 'Copyright © 2026 First Bite Labs'
    },

    search: {
      provider: 'local'
    },

    editLink: {
      pattern: 'https://github.com/firstbitelabsllc/claudux/edit/main/docs/:path',
      text: 'Edit this page'
    },

    lastUpdated: {
      text: 'Last updated',
      formatOptions: {
        dateStyle: 'short',
        timeStyle: 'short'
      }
    },

    outline: {
      level: [2, 3],
      label: 'On this page'
    },

    docFooter: {
      prev: 'Previous page',
      next: 'Next page'
    }
  }
})
