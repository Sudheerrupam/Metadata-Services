public class PageLayoutController {
    private static final String TOOLING_API_VERSION = 'v62.0';
    private static final String ENCODING = 'UTF-8';
    
    @AuraEnabled(cacheable=true)
    public static List<String> getObjects() {
        try {
            List<String> sObjectList = new List<String>();
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            
            for (Schema.SObjectType objType : globalDescribe.values()) {
                Schema.DescribeSObjectResult describeResult = objType.getDescribe();
                if (!describeResult.isCustomSetting() && describeResult.isCreateable()) {
                    sObjectList.add(describeResult.getName());
                }
            }
            
            sObjectList.sort();
            return sObjectList;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving objects: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<RecordTypeWrapper> getRecordTypes(String objectName) {
        if (String.isBlank(objectName)) {
            throw new AuraHandledException('Object name cannot be blank');
        }
        
        try {
            List<RecordTypeWrapper> recordTypes = new List<RecordTypeWrapper>();
            Schema.DescribeSObjectResult describeResult = Schema.getGlobalDescribe().get(objectName).getDescribe();
            Map<Id, Schema.RecordTypeInfo> rtMap = describeResult.getRecordTypeInfosById();
            
            // Add master record type first if it exists
            for (Schema.RecordTypeInfo rti : rtMap.values()) {
                if (rti.isMaster()) {
                    recordTypes.add(new RecordTypeWrapper(
                        rti.getRecordTypeId(),
                        rti.getName(),
                        rti.getDeveloperName(),
                        true
                    ));
                    break;
                }
            }
            
            // Add other active record types
            for (Schema.RecordTypeInfo rti : rtMap.values()) {
                if (!rti.isMaster() && rti.isActive() && rti.isAvailable()) {
                    recordTypes.add(new RecordTypeWrapper(
                        rti.getRecordTypeId(),
                        rti.getName(),
                        rti.getDeveloperName(),
                        false
                    ));
                }
            }
            
            return recordTypes;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving record types: ' + e.getMessage());
        }
    }
    
    public class RecordTypeWrapper {
        @AuraEnabled public String recordTypeId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String developerName { get; set; }
        @AuraEnabled public Boolean isMaster { get; set; }
        
        public RecordTypeWrapper(String recordTypeId, String name, String developerName, Boolean isMaster) {
            this.recordTypeId = recordTypeId;
            this.name = name;
            this.developerName = developerName;
            this.isMaster = isMaster;
        }
    }
    
    @AuraEnabled
    public static Map<String, Map<String, List<String>>> getAllLayoutsWithFields(String objectName, String recordTypeId) {
        if (String.isBlank(objectName)) {
            throw new AuraHandledException('Object name cannot be blank');
        }
        
        try {
            Map<String, Map<String, List<String>>> allLayouts = new Map<String, Map<String, List<String>>>();
            List<String> layouts;
            
            if (String.isNotBlank(recordTypeId)) {
                // Get layout assignment for specific record type
                String sql = 'SELECT Layout.Name FROM ProfileLayout WHERE RecordTypeId = \'' + 
                           String.escapeSingleQuotes(recordTypeId) + 
                           '\' AND TableEnumOrId = \'' + String.escapeSingleQuotes(objectName) + 
                           '\' LIMIT 1';
                String response = toolingAPISOQL(sql);
                
                if (String.isNotBlank(response)) {
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response);
                    List<Object> records = (List<Object>) responseMap.get('records');
                    
                    if (!records.isEmpty()) {
                        Map<String, Object> layoutRecord = (Map<String, Object>) records[0];
                        Map<String, Object> layoutObj = (Map<String, Object>) layoutRecord.get('Layout');
                        String layoutName = (String) layoutObj.get('Name');
                        layouts = new List<String>{ layoutName };
                    }
                }
            }
            
            if (layouts == null || layouts.isEmpty()) {
                layouts = getLayoutNameForObject(objectName);
            }
            
            // Rest of the existing getAllLayoutsWithFields logic
            for (String layout : layouts) {
                Map<String, List<String>> sectionFields = getFields(objectName, layout);
                Map<String, List<String>> sanitizedFields = new Map<String, List<String>>();
                
                for (String section : sectionFields.keySet()) {
                    List<String> fields = sectionFields.get(section);
                    List<String> sanitizedSectionFields = new List<String>();
                    
                    for (String field : fields) {
                        String sanitizedField = field
                            .replace('"', '')
                            .replace('\n', ' ')
                            .replace('\r', ' ')
                            .trim();
                        sanitizedSectionFields.add(sanitizedField);
                    }
                    
                    sanitizedFields.put(section.trim(), sanitizedSectionFields);
                }
                
                allLayouts.put(layout.trim(), sanitizedFields);
            }
            
            return allLayouts;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving layouts: ' + e.getMessage());
        }
    }
    
    public class RecordTypeInfo {
        @AuraEnabled public String recordTypeId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String developerName { get; set; }
        @AuraEnabled public Boolean isDefault { get; set; }
        
        public RecordTypeInfo(String recordTypeId, String name, String developerName, Boolean isDefault) {
            this.recordTypeId = recordTypeId;
            this.name = name;
            this.developerName = developerName;
            this.isDefault = isDefault;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getObjectLayout(String objectName) {
        if (String.isBlank(objectName)) {
            throw new AuraHandledException('Object name cannot be blank');
        }
        return getLayoutNameForObject(objectName);
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getLayoutFields(String objectName, String layout) {
        if (String.isBlank(objectName) || String.isBlank(layout)) {
            throw new AuraHandledException('Object name and layout must be specified');
        }
        return getFields(objectName, layout);
    }
    
    private static String toolingAPISOQL(String query) {
        if (String.isBlank(query)) {
            throw new IllegalArgumentException('Query cannot be blank');
        }
        
        try {
            String baseURL = URL.getOrgDomainUrl().toExternalForm() + 
                           '/services/data/' + TOOLING_API_VERSION + '/tooling/query?q=' + 
                           EncodingUtil.urlEncode(query, ENCODING);
            
            return HttpCallout.restGet(baseURL, 'GET', '');
        } catch (Exception ex) {
            throw new AuraHandledException('Tooling API query failed: ' + ex.getMessage());
        }
    }
    
    private static List<String> getLayoutNameForObject(String objectName) {
        List<String> layouts = new List<String>();
        
        String sql = 'SELECT Name FROM Layout WHERE TableEnumOrId = \'' + String.escapeSingleQuotes(objectName) + '\'';
        String response = toolingAPISOQL(sql);
        
        if (String.isNotBlank(response)) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(response);
            List<Object> records = (List<Object>) responseMap.get('records');
            
            Set<String> uniqueLayouts = new Set<String>();
            for (Object record : records) {
                Map<String, Object> layoutRecord = (Map<String, Object>) record;
                String layoutName = (String) layoutRecord.get('Name');
                if (String.isNotBlank(layoutName)) {
                    uniqueLayouts.add(layoutName);
                }
            }
            
            layouts.addAll(uniqueLayouts);
            layouts.sort();
        }
        
        return layouts;
    }
    
    private static Map<String, List<String>> getFields(String objectName, String layout) {
        Map<String, List<String>> sections = new Map<String, List<String>>();
        
        String layoutName = String.format('{0}-{1}', new List<String>{
            String.escapeSingleQuotes(objectName),
            String.escapeSingleQuotes(layout)
        });
        
        try {
            List<Metadata.Metadata> layouts = Metadata.Operations.retrieve(
                Metadata.MetadataType.Layout, 
                new List<String>{layoutName}
            );
            
            if (!layouts.isEmpty()) {
                Metadata.Layout layoutMd = (Metadata.Layout) layouts.get(0);
                Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe()
                    .get(objectName)
                    .getDescribe()
                    .fields.getMap();
                
                sections = processLayoutSections(layoutMd.layoutSections, fieldMap);
            }
            
            return sections;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving layout fields: ' + e.getMessage());
        }
    }
    
    private static Map<String, List<String>> processLayoutSections(
        List<Metadata.LayoutSection> layoutSections,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        Map<String, List<String>> sections = new Map<String, List<String>>();
        
        for (Metadata.LayoutSection section : layoutSections) {
            List<String> fields = new List<String>();
            
            for (Metadata.LayoutColumn column : section.layoutColumns) {
                if (column.layoutItems != null) {
                    fields.addAll(processLayoutItems(column.layoutItems, fieldMap));
                }
            }
            
            if (!fields.isEmpty()) {
                sections.put(section.label, fields);
            }
        }
        
        return sections;
    }
    
    private static List<String> processLayoutItems(
        List<Metadata.LayoutItem> items,
        Map<String, Schema.SObjectField> fieldMap
    ) {
        List<String> fields = new List<String>();
        
        for (Metadata.LayoutItem item : items) {
            if (String.isNotBlank(item.field) && fieldMap.containsKey(item.field)) {
                Schema.DescribeFieldResult fieldDesc = fieldMap.get(item.field).getDescribe();
                
                if (fieldDesc.getType() == Schema.DisplayType.REFERENCE) {
                    String relatedObject = fieldDesc.getReferenceTo()[0].getDescribe().getName();
                    fields.add(item.field + ' -> ' + relatedObject + '.Name');
                } else {
                    fields.add(item.field);
                }
            }
        }
        
        return fields;
    }
    
    // @AuraEnabled
    // public static String generateCSV(String objectName, String layoutName, Map<String, List<String>> sections) {
    //     if (String.isBlank(objectName) || String.isBlank(layoutName)) {
    //         throw new AuraHandledException('Object name and layout name must be specified');
    //     }
        
    //     List<String> csvData = new List<String>();
    //     csvData.add('Object Name,Page Layout Name,Section,Field');
        
    //     if (sections == null || sections.isEmpty()) {
    //         csvData.add(String.format('{0},{1},No Sections,No Fields', 
    //             new List<String>{objectName, layoutName}));
    //     } else {
    //         for (String sectionName : sections.keySet()) {
    //             for (String field : sections.get(sectionName)) {
    //                 if(field.contains(' -> ')) {
    //                     system.debug('RRR 174');
    //                     String lookupField = field.substringBefore(' -> ');
    //                     String relatedObject = field.substringAfter(' -> ');
    //                     system.debug('RRR 177 lookupField '+lookupField);
    //                     system.debug('RRR 178 relatedObject '+relatedObject);
    //                     csvData.add(String.format('{0},{1},{2},{3}',
    //                         new List<String>{
    //                             objectName,
    //                             layoutName,
    //                             sectionName,
    //                             lookupField
    //                         }
    //                     ));
    //                     csvData.add(String.format('{0},{1},{2},{3}',
    //                         new List<String>{
    //                             objectName,
    //                             layoutName,
    //                             sectionName,
    //                             relatedObject
    //                         }
    //                     ));
    //                 }
    //                 else{
    //                     system.debug('RRR 197');
    //                     csvData.add(String.format('{0},{1},{2},{3}',
    //                         new List<String>{
    //                             objectName,
    //                             layoutName,
    //                             sectionName,
    //                             field
    //                         }
    //                     ));
    //                 }
    //             }
    //         }
    //     }
        
    //     return String.join(csvData, '\n');
    // }
}