var Handlebars = require('handlebars')

var url = "http://fo.bar.baz/docs/classesNoFrame.html";
var error = JSON.stringify({a: "foobar", b: "bazbar", c: {nested: "values", more_nested: "vals"}},
                           null,
                           2
                          )

exports.error_html = new Handlebars.SafeString(`Could not reach the specified Javadoc URL, <code>${url}</code>. The response was: <pre>${error}</pre><div>Depending on the error type, you may wish to try a differnt Javadoc URL, or try again later. If you believe this to be an error on the parsing code, please file an issue on the <a href="http://github.com/levand/javadoc.zone">Github repository</a>.</div>`);
