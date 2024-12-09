@isTest
public class PageLayoutControllerTest {
    
    @isTest
    static void testGetObjects() {
        Test.startTest();
        List<String> objects = PageLayoutController.getObjects();
        //System.assertNotEquals(null, objects, 'The object list should not be null');
        System.assert(!objects.isEmpty(), 'The object list should not be empty');
        Test.stopTest();
    }

    @isTest
    static void testGetObjectLayout() {
        
        Test.startTest();
        PageLayoutControllerMock mock = new PageLayoutControllerMock();
        Test.setMock(HttpCalloutMock.class, mock);
        String objectName = 'Account';
        List<String> layouts = PageLayoutController.getObjectLayout(objectName);
        System.assertNotEquals(null, layouts, 'The layouts list should not be null');
        System.assert(!layouts.isEmpty(), 'The layouts list should not be empty');
        Test.stopTest();
    }

    @isTest
    static void testGetLayoutFields() {
       
        Test.startTest();
        Map<String, List<String>> layoutFields = PageLayoutController.getLayoutFields('Account', 'Account Layout');
        System.assertNotEquals(null, layoutFields, 'The layout fields map should not be null');
        System.assert(!layoutFields.isEmpty(), 'The layout fields map should not be empty');
        Test.stopTest();
    }

    @isTest
    static void testGenerateCSV() {
        Test.startTest();
        String csv = PageLayoutController.generateCSV('Account', 'Account Layout', new List<String>{'Name', 'Phone', 'Email'});
        System.assertNotEquals(null, csv, 'The CSV string should not be null');
        System.assert(csv.contains('Name'), 'The CSV should include the "Name" field');
        System.assert(csv.contains('Phone'), 'The CSV should include the "Phone" field');
        System.assert(csv.contains('Email'), 'The CSV should include the "Email" field');
        Test.stopTest();
    }

    @isTest
    static void testToolingAPISOQL() {
        Test.startTest();
        PageLayoutControllerMock mock = new PageLayoutControllerMock();
        Test.setMock(HttpCalloutMock.class, mock);
        String query = 'SELECT Name FROM Layout WHERE TableEnumOrId = \'Account\'';
        String response = PageLayoutController.toolingAPISOQL(query);
        System.assertNotEquals(null, response, 'The tooling API response should not be null');
        Test.stopTest();
    }

   
    private class PageLayoutControllerMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"records":[{"Name":"Account Layout"}]}');
            res.setStatusCode(200);
            return res;
        }
    }
}