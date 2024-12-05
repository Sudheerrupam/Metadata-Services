public class PageLayoutController {
    
    
    @Auraenabled(cacheable=true)
    public static List<string> getObjects()
    {
        List<String> sObjectList = new List<String>();
        for (Schema.SObjectType objType : Schema.getGlobalDescribe().values()) {
            Schema.DescribeSObjectResult describeResult = objType.getDescribe();
            if (!describeResult.isCustomSetting() && describeResult.isCreateable()) {
                String name = describeResult.getName();
                sObjectList.add(name);
            }
        }
        sObjectList.sort();
        System.debug('Get Objects:' + sObjectList);
    
        return sObjectList;
    }
    
    @Auraenabled(cacheable=true)
    public static List<string> getObjectLayout(string objectName)
    {
        return getLayoutNameForObject(objectName);
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getLayoutFields(String objectName, String layout) {
    return getFields(objectName, layout);
}

    
    
    public static String toolingAPISOQL(String query) {
        try {
            
            String baseURL = URL.getOrgDomainUrl().toExternalForm() + '/services/data/v62.0/tooling/query?q=' + EncodingUtil.urlEncode(query, 'UTF-8');
            //String baseURL='callout:ToolingRest?';
            //return HttpCallout.restGet( baseURL +'q='+ (query.replace(' ', '+')),'GET', );
            
            return HttpCallout.restGet(baseURL, 'GET','');
        } catch (Exception ex) {
            System.debug('Exception in toolingAPISOQL: ' + ex.getMessage());
            return ex.getMessage();
        }
    }
    
    
   static List<String> getLayoutNameForObject(String objectName) {
    String sql = 'SELECT Name FROM Layout WHERE TableEnumOrId = \'' + objectName + '\'';
    String body = toolingAPISOQL(sql);
    System.debug('Tooling API Body: ' + body);

    List<String> layouts = new List<String>();
    if (String.isNotBlank(body)) {
        
        Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(body);
        List<Object> records = (List<Object>) bodyMap.get('records');
       
        for (Object record : records) {
            Map<String, Object> r = (Map<String, Object>) record;
            String layoutName = (String) r.get('Name');
            if (layoutName != null && !layouts.contains(layoutName)) {
                layouts.add(layoutName);
            }
        }
        System.debug('Retrieved Layouts: ' + layouts);
    }
    return layouts;
}
    
static Map<String, List<String>> getFields(String objectName, String layout) {
    String layoutName = String.format('{0}-{1}', new String[] {objectName, layout});
    List<Metadata.Metadata> layouts = Metadata.Operations.retrieve(Metadata.MetadataType.Layout, new List<String> {layoutName});
    System.debug('Page Layouts:' + layouts);

    Map<String, List<String>> sections = new Map<String, List<String>>();
    if (!layouts.isEmpty()) {
        Metadata.Layout layoutMd = (Metadata.Layout) layouts.get(0);
        System.debug('Layouts:' + layoutMd);
        for (Metadata.LayoutSection section : layoutMd.layoutSections) {
            List<String> fields = new List<String>();
            for (Metadata.LayoutColumn column : section.layoutColumns) {
                if (column.layoutItems != null) {
                    for (Metadata.LayoutItem item : column.layoutItems) {
                        if (item.field != null) {
                            fields.add(item.field);
                        }
                    }
                }
            }
            if (!fields.isEmpty()) {
                sections.put(section.label, fields);
            }
        }
    }
    System.debug('Sections with Fields:' + sections);
    return sections;
}

    @AuraEnabled
public static String generateCSV(String ObjectName, String LayoutName, List<String> fieldsList) {
    List<String> csvData = new List<String>();
    csvData.add('Object Name,Page Layout Name,Fields');

    if (fieldsList == null || fieldsList.isEmpty()) {
        csvData.add(ObjectName + ',' + LayoutName + ',No Fields Selected');
    } else {
        String fieldsString = String.join(fieldsList, ';');
        csvData.add(ObjectName + ',' + LayoutName + ',' + fieldsString);
    }

    return String.join(csvData, '\n');
}
}
    
