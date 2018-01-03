var HandlebarsGenerator = require('handlebars-generator');

HandlebarsGenerator.generateSite('templates', '.build')
    .then(function () {
        console.log('successfully generated pages');
    }, function (e) {
        console.error('failed to generate pages', e);
    })
;
