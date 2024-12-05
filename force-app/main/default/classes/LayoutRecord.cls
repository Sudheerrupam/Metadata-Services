public class LayoutRecord {
    
    public Integer size {get;set;} 
    public Integer totalSize {get;set;} 
    public Boolean done {get;set;} 
    public Object queryLocator {get;set;} 
    public String entityTypeName {get;set;} 
    public List<Record> records {get;set;} 
    
    public class Layout {
        public Attributes attributes {get;set;} 
        public String Name {get;set;} 
    }
    public class Attributes {
        public String type_Z {get;set;} // in json: type
        public String url {get;set;} 
    }
    public class Record {
        public Attributes attributes {get;set;} 
        public Layout Layout {get;set;} 
    } 
    
    public static LayoutRecord parse(String json){
        return (LayoutRecord) System.JSON.deserialize(json, LayoutRecord.class);
    }
}