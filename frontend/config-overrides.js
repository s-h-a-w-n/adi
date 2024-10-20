const { override, disableEsLint, addWebpackModuleRule } = require('customize-cra');

module.exports = override(
  disableEsLint(),
  addWebpackModuleRule({
    test: /\.css$/,
    use: [
      {
        loader: 'css-loader',
        options: {
          sourceMap: false,
        },
      },
    ],
  })
);