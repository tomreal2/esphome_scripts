var request = require('request');

request.post(
    'http://192.168.1.217/api.cgi?cmd=Login',
    [{"cmd":"Login","action":0,"param":{"User":{"userName":"admin","password":"Havea6and3"}}}],
    function (error, response, body) {
        if (!error && response.statusCode == 200) {
            console.log(body);
        }
    }
);