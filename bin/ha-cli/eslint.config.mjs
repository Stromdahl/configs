import globals from 'globals';

export default [
  {
    files: ['ha'],
    languageOptions: {
      ecmaVersion: 'latest',
      sourceType: 'script',
      globals: {
        ...globals.node,
        WebSocket: 'readonly',
        fetch: 'readonly',
      },
    },
    rules: {
      complexity: ['error', { max: 8 }],
    },
  },
];
