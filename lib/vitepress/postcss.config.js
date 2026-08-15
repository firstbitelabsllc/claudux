// Empty PostCSS config to override any parent project config
// This prevents VitePress from loading PostCSS configs from parent directories
// The generated docs/package.json declares "type": "module", so ESM only.
export default {
  plugins: []
}