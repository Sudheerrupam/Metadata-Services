public class HttpCallout {

    public static String getAccessToken() {
        String clientId = '3MVG9k02hQhyUgQB_z2CnaAq9eW32fT3HuTCMPiT0T_s75fyHLhkZyLfenxu2.s_dG8wz7gqamWGwQeroXGv5';
        String clientSecret = '2E2702C7B475E4A29ECEE938B3E9BC1A7C109A196028D2E255562B6C61F2D4B8';
        String tokenUrl='https://login.salesforce.com/services/oauth2/token';
        String userName='sudheer@conscendo.io';
        String password = 'Ammadaddyama@2024LNebJCiBU8Ii0iBlCp0BeE4Nf';
 
        HttpRequest req = new HttpRequest();
        req.setEndpoint(tokenUrl);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
       
        // Build the request body
        String body = 'grant_type=password' +
                      '&client_id=' + clientId +
                      '&client_secret=' + clientSecret +
                      '&username=' + userName +
                      '&password=' + password;
        req.setBody(body);
       
        Http http = new Http();
        HttpResponse res;
        try {
            res = http.send(req);
            if (res.getStatusCode() == 200) {
                // Parse the JSON response to extract the access token
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (String) responseMap.get('access_token');
            } else {
                System.debug('Failed to retrieve access token. Status: ' + res.getStatusCode());
                System.debug('Response: ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('Error while calling token API: ' + e.getMessage());
        }
        return null;
    }
    
    public static String restGet(String endPoint, String method, String sid) {
        try
        {
            Http h = new Http();
            HttpRequest hr = new HttpRequest();
            hr.setHeader('Authorization', 'Bearer ' + getAccessToken());
            hr.setTimeout(60000);
            hr.setEndpoint(endPoint);
            hr.setMethod(method);
            HttpResponse r = h.send(hr);
            return r.getBody();
        }
        catch(Exception ex)
        {
            system.debug('Exception in tooling API Call:'+ ex.getMessage());
            return ex.getMessage();
        }
    }
}