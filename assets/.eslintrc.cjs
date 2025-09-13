module.exports = {
  root: true,
  env: { browser: true, es2020: true, jest: true },
  extends: [
    'eslint:recommended',
    'plugin:react/recommended',
    'plugin:@typescript-eslint/recommended',
    'plugin:@typescript-eslint/eslint-recommended',
    'prettier',
    'plugin:prettier/recommended',
    'plugin:react-hooks/recommended',
  ],
  ignorePatterns: ['dist', '.eslintrc.cjs'],
  parser: '@typescript-eslint/parser',
  plugins: ['@typescript-eslint', 'react-refresh'],
  rules: {
    'react-refresh/only-export-components': ['warn', { allowConstantExport: true }],
    'react/react-in-jsx-scope': 'off',
    '@typescript-eslint/ban-ts-comment': 'off',
    "linebreak-style": "off",
    "no-restricted-imports": [
      "error",
      {
        "paths": [
          {
            "name": "primereact/button",
            "importNames": ["Button"],
            "message": "Use WdButton instead Button"
          }
        ]
      }
    ],
    "react/forbid-elements": [
      "error",
      {
        "forbid": [
          {
            "element": "Button",
            "message": "Use WdButton instead Button"
          }
        ]
      }
    ]
  },
};
