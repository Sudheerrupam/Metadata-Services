public class MetadataController {
    @AuraEnabled(cacheable=true)
    public static List<String> getAllObjects() {
        List<String> sObjectList = new List<String>();
        for (Schema.SObjectType objType : Schema.getGlobalDescribe().values()) {
            String name = objType.getDescribe().getName();
            sObjectList.add(name);
        }
        sObjectList.sort();
        return sObjectList;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getLayoutsForObject(String objectName) {
        List<String> layoutNames = new List<String>();
        
       List<Metadata.Metadata> layouts = Metadata.Operations.retrieve(
            Metadata.MetadataType.Layout, 
            new List<String>{objectName + '*'}
        );  
        system.debug('Layouts :' +layouts);
        for (Metadata.Metadata layoutMetadata : layouts) {
            Metadata.Layout layout = (Metadata.Layout)layoutMetadata;
            // Extract the layout name after the object name and hyphen
            String fullLayoutName = layout.fullName;
            String layoutName = fullLayoutName.substringAfter(objectName + '-');
            layoutNames.add(layoutName);
        }
        
        layoutNames.sort();
        return layoutNames;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getLayoutSections(String objectName, String layoutName) {
        List<String> sectionNames = new List<String>();
        
        try {
            List<Metadata.Metadata> pageLayouts = Metadata.Operations.retrieve(
                Metadata.MetadataType.Layout,
                new List<String>{objectName + '-' + layoutName}
            );
            
            if (!pageLayouts.isEmpty()) {
                Metadata.Layout layout = (Metadata.Layout)pageLayouts[0];
                
                for (Metadata.LayoutSection section : layout.layoutSections) {
                    sectionNames.add(section.label);
                }
            }
        } catch (Exception ex) {
            System.debug('Error retrieving layout sections: ' + ex.getMessage());
            throw new AuraHandledException('Unable to retrieve layout sections.');
        }
        
        return sectionNames;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getFieldsInLayoutSection(String objectName, String layoutName, String sectionName) {
        List<String> fieldList = new List<String>();
        
        try {
            List<Metadata.Metadata> pageLayouts = Metadata.Operations.retrieve(
                Metadata.MetadataType.Layout,
                new List<String>{objectName + '-' + layoutName}
            );
            
            if (!pageLayouts.isEmpty()) {
                Metadata.Layout layout = (Metadata.Layout)pageLayouts[0];
                
                for (Metadata.LayoutSection section : layout.layoutSections) {
                    if (section.label == sectionName) {
                        Set<String> fieldSet = new Set<String>();
                        
                        for (Metadata.LayoutColumn column : section.layoutColumns) {
                            if (column.layoutItems != null) {
                                for (Metadata.LayoutItem item : column.layoutItems) {
                                    if (item.field != null) {
                                        fieldSet.add(item.field);
                                    }
                                }
                            }
                        }
                        
                        fieldList.addAll(fieldSet);
                        break;
                    }
                }
            }
        } catch (Exception ex) {
            System.debug('Error retrieving layout fields: ' + ex.getMessage());
            throw new AuraHandledException('Unable to retrieve layout fields.');
        }
        
        return fieldList;
    }
}