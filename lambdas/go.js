var util = require('./util.js');
var search = require('./search.js');
var mavenComparator = require('./mavenComparator.js');

// Given the results of `search`, find the most relevant one and return it's url
var mostRelevantUrl = function(results){
    results = results.sort((a, b) => mavenComparator.mavenVersionSortComparer(b.version, a.version));
    return results.map(r => r.url).shift();
}


exports.handler = function(event, context, callback) {

    var args = event.pathParameters;

    var redirect = function(url, code) {
        callback(null, { statusCode: code.toString(),
                         headers: {'Location': url} });
    }

    util.checkRequiredArgs(args, "className")
        .then(() => search.search(args.className))
        .then(results => mostRelevantUrl(results))
        .then(url => {
            if(url) {
                redirect(url, 301);
            } else {
                search.respond_html(callback, {results: null,
                                               missing: args.className,
                                               paths: {css: "../css",
                                                       add: "../add",
                                                       index: "../index"}});
            }})
        .catch(e => {
            if (e.type) {
                callback(null, util.errorResponse(event, e));
            } else {
                console.log("Unexpected Error", e)
                callback(null, util.errorResponse(event,
                                                  util.err(500,
                                                           "InternalServerError",
                                                           "Internal Server Error",
                                                           {cause: e})));
            }
        });

}
