/**************************************
enhanced DynDataViewerApexContr class
which return apex exception results to
the caller Javascript helper class/
This class handle exception and pass
the results to  the .js helper class
**************************************/
public class DynDataViewerApexContr_WEH  
{

	@AuraEnabled
	/*********************************
	used  to reditrect  from Lightning
	to a record 
	*********************************/
	public static String getBaseUrl () 
	{
		return String.valueOf(System.URL.getSalesforceBaseUrl());
	}

   /*************************************************************************************************
	We need to know  the ParentRecord Id on DestinationObject in order to pass it to the Inner  comp.
	param: fieldName  = Name of  the Parent Lookup  on DestObject  
	param: ObjectName = Name of  the Destination Objec 
	DestinationRecordID = Id  of the Destination record
	*************************************************************************************************/
    public static String getParentrecordID(String ObjectName,String fieldName, String DestinationRecordID)
	{
	String res = null;

	String queryu = 'Select ' + fieldName +  ' from ' + ObjectName + ' where id = \'' + DestinationRecordID + '\'';
	try
	{
	List<SObject> theObj = Database.query(queryu);
	SObject theO = theObj[0]; //we must have one

	res = String.valueOf(theO.get(fieldName));
	}
	catch(Exception e)
	{
	//handle exception only in aura Enable methods
	//throw e; 
	//return 'Invalid RecordID  for ' + fieldName + ' in  ' + ObjectName;
	}


	return res;
	}
 

    @AuraEnabled
	/******************************************************************************************************
	retrieve config  data  from database and return it  into an SetupDataTable
	IMPORTANT to  get here the ParentRecordID too using the DestinationRecordID and Setup Data
	public static List<SetupDataTable> getSetupObjRecords(String strObjectName, String DestinationRecordID)
	******************************************************************************************************/
	//public static List<SetupDataTable> getSetupObjRecords(String DestinationRecordID)
	public static ResponseData4JS getSetupObjRecords(String DestinationRecordID)
	{
	    List<SetupDataTable> res = new List<SetupDataTable>();
		ResponseData4JS resDS;
		try
		{	        
		//gwt the Name of the strObjectName from the DestinationRecordID. the  first  3  chars  determine the object
		String strObjectName = String.valueOf(Id.valueOf(DestinationRecordID).getSObjectType());




		List<DynamicDataViewerConfigurator__c> DLVCs = [Select SourceObjectName__c, 
		                                                ParentFieldNameOn_Dest__c,ParentFieldNameOn_Source__c,
														columnList_sourceType__c,
														SourceColumnList__c,
														Field_Label_List__c
		                                                from DynamicDataViewerConfigurator__c 
														where DestinationObjectName__c = :strObjectName
													    and Active__c = true];

		//in case of error in the for  try  to pass error only  to the wrong Component												  
        for(DynamicDataViewerConfigurator__c DLVC :DLVCs)
			{
			SetupDataTable sdt =  new SetupDataTable();
			//for each item try  to get the ID of the Parent lookup  based on Destination RecordID. THIS MEAN SOQL/record!!!
			sdt.ParentRecordID = getParentrecordID(strObjectName,DLVC.ParentFieldNameOn_Dest__c,DestinationRecordID);

			sdt.childObjName = DLVC.SourceObjectName__c;

		    //get here the label of the child Object
		    Schema.DescribeSobjectResult[] results = Schema.describeSObjects(new string[] {sdt.childObjName} );
		    String ChildObjLabel =  results[0].getLabel();

			sdt.childObjLabel = ChildObjLabel;  
			sdt.childObjNamePlural = results[0].getLabelPlural();

			sdt.LookupFieldNameOnDest = DLVC.ParentFieldNameOn_Dest__c;
			sdt.LookupFieldNameOnSouce = DLVC.ParentFieldNameOn_Source__c;

			String colSourcetype = DLVC.columnList_sourceType__c;
			if(colSourcetype == 'Manual')
				{
				sdt.SourceColumnNames = DLVC.SourceColumnList__c;
				sdt.SourceColumnLabels = DLVC.Field_Label_List__c;
				res.add(sdt);
				}
			else
			   { 
				List<DataTableColumns> DTCols;
				if(colSourcetype == 'FieldSet' )
				   {
				   DTCols = getFieldSetcolumns(DLVC.SourceObjectName__c, DLVC.SourceColumnList__c);
				   }

				if(colSourcetype == 'RelatedList' )
				   {
				   System.debug('DLVC.SourceObjectName__c='+ DLVC.SourceObjectName__c + ' DLVC.SourceColumnList__c= '+ DLVC.SourceColumnList__c);
				   DTCols = getRL_Fields(DLVC.SourceObjectName__c, DLVC.SourceColumnList__c);
				   }

				List<String> lstFieldsToQuery = new List<String>();
				List<String> lstLabelsToQuery = new List<String>(); 
				for(DataTableColumns DTC :DTCols)
				{
					lstFieldsToQuery.add(DTC.fieldName);
					lstLabelsToQuery.add(DTC.label);
				}

				sdt.SourceColumnNames = String.join(lstFieldsToQuery, ',');	 
				sdt.SourceColumnLabels = String.join(lstLabelsToQuery,',');  
				res.add(sdt);
				}

			} //end of for 
		resDS = new ResponseData4JS(true,'');
		resDS.values.put('setupData',res);
		}
		catch (Exception e)
		{
		resDS = new ResponseData4JS(false,'Exception occured in getSetupObjRecords: ' +  e.getMessage() + ' ' + e.getLineNumber() );
		}


		return resDS;
	}
	   

    @AuraEnabled
	/****************************************************************************************************
	Called by getSetupObjRecords in case columns are from a fieldSet.
	strObjectName:  Name of  the ChildSource  object
	strFieldSetName:Name of the FieldSet on ChildSource
	OBJ. This methods should not  be Auraenabled
	****************************************************************************************************/
    public static List<DataTableColumns> getFieldSetcolumns(String strObjectName, String strFieldSetName)
    {   
        List<DataTableColumns> lstDataColumns = new List<DataTableColumns>();	
	             
        //Get the fields from FieldSet using some metadata  classes. Viva Schema!
        Schema.SObjectType SObjectTypeObj = Schema.getGlobalDescribe().get(strObjectName);
		if(SObjectTypeObj == NULL)
		   return lstDataColumns;
        Schema.DescribeSObjectResult DescribeSObjectResultObj = SObjectTypeObj.getDescribe();            
        Schema.FieldSet fieldSetObj = DescribeSObjectResultObj.FieldSets.getMap().get(strFieldSetName);
		System.debug('fieldSetObj: ' + fieldSetObj);
        
        //we use later to nicely format the comma separated
        List<String> lstFieldsToQuery = new List<String>();
        
		if(fieldSetObj == null)
		   return lstDataColumns;
        
        for( Schema.FieldSetMember eachFieldSetMember : fieldSetObj.getFields() )
        {
		    System.debug('eachFieldSetMember: ' + eachFieldSetMember);
            String dataType = String.valueOf(eachFieldSetMember.getType()).toLowerCase();

            //Special case handling for datatime. More might came later during test.
			//We do not get the exact type from schema object which matches to lightning:datatable component structure
            if(dataType == 'datetime')
            {
                dataType = 'date';
            }
            //Create an inner class instance and store label, fieldname and type.
            DataTableColumns datacolumns = new DataTableColumns( String.valueOf(eachFieldSetMember.getLabel()) , 
                                                                String.valueOf(eachFieldSetMember.getFieldPath()), 
                                                                String.valueOf(eachFieldSetMember.getType()).toLowerCase() );

            lstDataColumns.add(datacolumns);
        }

        return lstDataColumns;
    }



	@AuraEnabled
	/*****************************************************************************************************
	get  the columns from the related list f object SourceObjName on page layout PageLayoutNameOnParent
	Possible issue:  Ther  name of  the rleated List for  Standard Object might be wierd
	OBJ. This methods should not  be Auraenabled
	*****************************************************************************************************/
    public static List<DataTableColumns> getRL_Fields(String SourceObjName, String PageLayoutNameOnParent)
    {
	List<DataTableColumns> lstDataColumns = new List<DataTableColumns>();



    /************ collect fields in a Map START ****************************************/
    Map<String, Schema.SObjectType> schemaMap = Schema.getGlobalDescribe();
    Schema.SObjectType leadSchema = schemaMap.get(SourceObjName);
	if(leadSchema ==  NULL)    //no such Object
	   return lstDataColumns;  
    Map<String, Schema.SObjectField> fieldMap = leadSchema.getDescribe().fields.getMap(); 
    System.Debug('fieldMap ' + fieldMap.keySet());
    //need fieldMap to get the Label & type of field since Relatedlist has only the Name    
    /************ collect fields in a Map END ******************************************/
     
    /************ collect page layout info START **************************************************************/    
    Metadata.layout attachmentLayout =  new Metadata.layout();
    List<String> layoutList = new List<String>{PageLayoutNameOnParent};
    List<Metadata.Metadata> components = Metadata.Operations.retrieve(Metadata.MetadataType.Layout, layoutList);
	if(components ==  NULL || components.size() == 0)     //no  such a page layout
	   return lstDataColumns;    
    attachmentLayout = (Metadata.layout)components.get(0); //check what else items
    List<Metadata.RelatedListItem> relatedLists = attachmentLayout.relatedLists;
    /************ collect page layout info END ****************************************************************/
    
	
	//iterate through relatedLists and find ours.    
    for(Metadata.RelatedListItem item: relatedLists)
    	{
        String RelatelListu = String.valueOf(item.RelatedList);  
        System.Debug('RelatelListu = ' + RelatelListu);  
		
		DataTableColumns datacolumns;
        
        if(item.RelatedList == 'RelatedAccountSalesTeam' && SourceObjName == 'AccountTeamMember')
        { //this is a salesforce non-customizable RelList and has only 3 displayable columns 
          datacolumns = new DataTableColumns('User','User.Name','text');		  
		  lstDataColumns.add(datacolumns);           
          return lstDataColumns;  
        }

		//for other  standard  objects  do  what we have above!!!!
        Boolean StandardPObj = false;
        if(RelatelListu == 'RelatedOpportunityList' && SourceObjName == 'Opportunity')
	       StandardPObj = true;
            
        if(RelatelListu.startsWith(SourceObjName) == false && StandardPObj == false) 
           continue; 
        else
           {
                //String colItem;  
                System.debug('item.fields = ' + item.fields);
                if(item.fields == null)
                    continue;  
                for(Integer i = 0; i <item.fields.size(); i++)
                    {
                     system.Debug(item.fields[i]);
                     if(fieldMap.get(item.fields[i]) ==  NULL)
					    {
						//BE CAREFULL HERE because some system fields might have different 
						//naming convention on Reated list ex: CreatedDate is CREATED_DATE
                        if(item.fields[i] == 'CREATED_DATE')
						   item.fields[i] = 'CreatedDate';
                        else if(item.fields[i].startswith('OWNER'))
						   item.fields[i] = 'OwnerId';
                        else   
						   continue;
						}

                    if(item.fields[i] == 'Name')
                           continue;  //exclude Name because is unlikelly to need the name of RelatedList recod  
 
                    if(fieldMap.get(item.fields[i]).getDescribe().getType() == Schema.DisplayType.REFERENCE)
					   {
					    String FN = item.fields[i];
						if(FN.endsWith('Id'))         //take care because  of  special cases  
						   FN = FN.left(FN.length()-2);

                        FN = FN.replace('__c','__r'); 
 
						datacolumns = new DataTableColumns(fieldMap.get(item.fields[i]).getDescribe().getLabel(),
						                                   FN + '.Name',
				    								      'text');
					   }
                    else
                        {
						datacolumns = new DataTableColumns(fieldMap.get(item.fields[i]).getDescribe().getLabel(),
						                                   String.valueOf(item.fields[i]),
														   String.valueOf(fieldMap.get(item.fields[i]).getDescribe().getType()));

						}

						lstDataColumns.add(datacolumns);
                    }//end of for
            //do not check the next  Related list bwcause we found it!    
	        break;
           }//end of else
        }
     return lstDataColumns;   
    } 

    @AuraEnabled
	/*****************************************************************************************************************
	//method converts  List of  SObj  returning from a query  into a list of list of string in order to pass it later 
	to a lightning:datatable.

	//cols = 'Account__r.Name,Name__c,Product_Specialty__c,Active__c,User__c,User__r.Name';
	THIS METHOD IS USED BY THE INNER LIGHTNING COMPONENT
	the real data is  stored in a List<List<string>>   the result will be processed by Javascript of the comp. helper
	*****************************************************************************************************************/
    public static ResponseData4JS getDynamicObjs(ID theParentrecID,String cols, String ObjName, String ParentFieldAPI)
    {
	    List<List<string>> Res =  new List<List<string>>();
		ResponseData4JS resDS;

		try
		{	        
		/************************** Get the raw data START *********************/
	    String Queryu;
        String Wheru;
		//not  alway have  WHERE clause!!! 
		if(theParentrecID != NULL || ParentFieldAPI != NULL)
		   Wheru = ' Where ' + ParentFieldAPI + ' = \'' + theParentrecID + '\''; 

        Queryu = 'Select Id,' + cols + ' from ' + ObjName;
		if(Wheru != NULL)
		   Queryu =  Queryu + Wheru;

        System.debug('Queryu = ' +  Queryu);
		List<SObject> ObjRecs;
		try
		{
		ObjRecs = Database.query(Queryu);
		}
		catch(Exception myex)
		{
		resDS =  new ResponseData4JS(false,'exception occured in getDynamicObjs: ' + myex.getMessage() + ' ' + myex.getLineNumber() +'\r\n Wrong query: ' + Queryu);
		return resDS;
		}


		System.debug('cols = ' + cols);
	   /************************** Get the raw data END ***********************/


	    /*** Make the data flat ***/
		For(SObject therec :ObjRecs)
			{
			   Map<String,Object> mapPopulatedFields = therec.getPopulatedFieldsAsMap();
			   System.debug('record str = ' + mapPopulatedFields);

			   List<String> resRecord = new List<String>();

			   Integer startingDotIndex = 0;
			   Boolean FirstItem =  true; 
			   for(String keyu :cols.split(','))
			   {

			   /********* Add ID too  *********/
			   if(FirstItem == true)
				{
				resRecord.add(therec.id);
				FirstItem =  false;
				}
			   /********* Add ID too *********/

				 Object obj;
				 System.debug('column = ' + keyu);

				 //in case we have multiple  relationships we have to alter this a bit
				 if(keyu.contains('.') == true)
				 {
				   String colValue = getSomething(mapPopulatedFields,keyu);
			       //ALWAYS ADD a VALUE TO COLUMN. 
			      if(colValue == null)
			         colValue = '';
                  if(colValue == 'ERROR') //just to detect possible errors
				     colValue = 'N.A.'; 

                   System.debug('ADDING field: ' + keyu + ' = ' + colValue);
				   resRecord.add(colValue);
				 }
				 else
				 {
				   obj = mapPopulatedFields.get(keyu);
			       //ALWAYS ADD a VALUE TO COLUMN. 
				    if(obj == null)
			          obj = '';
			       System.debug('ADDING simple field: ' + keyu + '=' + obj);
				   resRecord.add(String.valueOf(obj));
				 }
			   }
			 Res.add(resRecord);
			}

		resDS =  new ResponseData4JS(true,'');
		resDS.values.put('DataTable_2D',res);
		}
		catch (Exception e)
		{
		    resDS =  new ResponseData4JS(false,'exception occured in getDynamicObjs: ' + e.getMessage() + ' ' + e.getLineNumber());
		}

        return resDS;	       
    } 
	
	/************************************************************************************************
	function  need to  be  called  recursivelly  as long as columnstring contain '.'
	Method called from inside getDynamicObjs
	BEST METHOD IN WHILE SOLUTION!
	************************************************************************************************/
    public static string getSomething(Map<String,Object> PopulatedFieldsAsMap, String columnswithDot)
	{
	string res;
	System.debug('START getSomething');
	System.debug('PopulatedFieldsAsMap: ' + PopulatedFieldsAsMap);
	System.debug('columnswithDot: ' + columnswithDot);
  
	Integer firstIndexOfDot = columnswithDot.indexOf('.');
	Integer lastIndexOfDot = columnswithDot.lastIndexOf('.');

	String firstcol = columnswithDot.left(firstIndexOfDot);
	System.debug('firstcol: ' + firstcol);

	if(firstIndexOfDot != lastIndexOfDot)
	{
	System.debug('MULTIPLE DOTs');
	String restCols = columnswithDot.substring(firstIndexOfDot+1);
	System.debug('restCols: ' + restCols);
	//if columnswithDot contains more than 1 Dot, remove the first 
	//and call this function again with the restCols AND a new map
	Object obj = PopulatedFieldsAsMap.get(firstcol);
	SObject a = (SObject)obj; 
	if(a == null)
	   return 'N/A';
	Map<String,Object> innerPopulatedFieldsAsMap =  a.getPopulatedFieldsAsMap();
	res = getSomething(innerPopulatedFieldsAsMap,restCols);
	}
    else
    {
	         System.debug('ONE DOT');
			 string realKey = columnswithDot.split('\\.')[0];
			 string realFN = columnswithDot.split('\\.')[1];
			 //system.Debug('realKey = ' + realKey + 'realFN = ' + realFN);
			 Object obj = PopulatedFieldsAsMap.get(realKey);
			 System.debug('obj = ' + obj);
			 SObject a = (SObject)obj; 
			 	if(a == null)      
	               return 'N/A';  
			 Map<String, Object> fieldsToValue = a.getPopulatedFieldsAsMap();
			 for (String fieldName : fieldsToValue.keySet()) 
			    {
				    if(fieldName == realFN)
					{
					   System.debug('Getting: ' + columnswithDot + ' = ' +  fieldsToValue.get(fieldName));
					   res =String.valueOf(fieldsToValue.get(fieldName));
					}
				}
    }

	return res;
	}

		/**************************
		Inner class to store setup
		data for outer component
		attribute: mySetupdata
		**************************/
	    public class SetupDataTable 
		{
        @AuraEnabled  
        public String childObjName {get;set;}

        @AuraEnabled
        public String childObjNamePlural {get;set;} //added later

        @AuraEnabled       
        public String LookupFieldNameOnDest {get;set;}

        @AuraEnabled       
        public String LookupFieldNameOnSouce {get;set;}
        @AuraEnabled
        public String SourceColumnNames {get;set;}

        @AuraEnabled
        public String SourceColumnLabels {get;set;} //added later

        @AuraEnabled
        public String ParentRecordID {get;set;}  

		//add ChildObjectlabel for better UI  experience
        @AuraEnabled  
        public String childObjLabel {get;set;} 

		public SetupDataTable()
			{

			}
        
		}

	/****************************
	we need only  the field Names
	but  maybe later we use Label
	and Type too. ***************
	****************************/
    public class DataTableColumns 
	{
        @AuraEnabled
        public String label {get;set;}
        @AuraEnabled       
        public String fieldName {get;set;}
        @AuraEnabled
        public String type {get;set;}
        
        public DataTableColumns(String label, String fieldName, String type)
		{
            this.label = label;
            this.fieldName = fieldName;
            this.type = type;            
        }
    }


/***************************
Generic helper class which
should be used always when
working with lightning comp
It allows to handle errors
from server-side and nicely
display inside the component
***************************/
public class ResponseData4JS
{

    @AuraEnabled public Boolean isSuccess { get; set; }

    @AuraEnabled public String message { get; set; }

	//the value of  the map  is the real data structure we need
	//regarless  to salesforce type .js will process as Object.
    @AuraEnabled public Map<Object, Object> values { get; set; }
     

public ResponseData4JS(Boolean isSuccess, String msg)
  {
   this.isSuccess = isSuccess;
   this.message = msg;
   this.values = new Map<Object, Object>();
  }
}

}