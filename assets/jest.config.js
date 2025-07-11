module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'jsdom',
  roots: ['<rootDir>'],
  moduleDirectories: ['node_modules', 'js'],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/js/$1',
    '\.scss$': 'identity-obj-proxy', // Mock SCSS files
  },
  transform: {
    '^.+\.(ts|tsx)$': 'ts-jest',
    '^.+\.(js|jsx)$': 'babel-jest', // Add babel-jest for JS/JSX files if needed
  },
};
