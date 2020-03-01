/************************************************
 My guess is that  this class can not directly
 interact with the Apex controller and this is
 why we need the helper
 ***********************************************/
({
   setViewType : function (component, event, helper)
   {
		//try to set here the viewType   
		var eventSourceAttr;
		var evSource = event.getSource();
		try
		{
			eventSourceAttr = event.getSource().get("v.value");
			if(eventSourceAttr == 'Card')
			{
			   component.set('v.viewType','Table');
			}

			if(eventSourceAttr == 'Table')
			{
			   component.set('v.viewType','Card');
			}
		}
        catch(error)
		{

		}		
		
   }
   ,
   doInit : function(component, event, helper) 
    {   //here can initiate the component's attributes but this can be transferred to the helper too.
	    
		var vtp = component.get("v.viewType");
		if(vtp != undefined)
		   return;

        /****************** START *********************/
        var updatedRLFieldList = component.get("v.mycolumnsLst"); //this has  to be filled 
        
		var commaDelimitedFieldNames =  component.get("v.mycolumnNames");   //this is the source 
		var commaDelimitedFieldNamesArray;
		if(commaDelimitedFieldNames != undefined)
		   {
			commaDelimitedFieldNamesArray = commaDelimitedFieldNames.split(',');  
		   }
                    

        var commaDelimitedFieldLabels = component.get("v.mycolumnLabels");   //this is the source 
		
		var commaDelimitedFieldLabelsArray;
		if(commaDelimitedFieldLabels != undefined)  //2020.01.05.
           commaDelimitedFieldLabelsArray = commaDelimitedFieldLabels.split(',');  
		
		if(commaDelimitedFieldNamesArray == undefined)
		   return;  //2020.01.05.
		
        for(var i = 0; i < commaDelimitedFieldNamesArray.length; i++)
           {
            var fieldName = commaDelimitedFieldNamesArray[i];
			//if v.mycolumnLabels is populated try to  use it
            var fieldLabel = fieldName;
			if(commaDelimitedFieldLabelsArray != undefined && commaDelimitedFieldNamesArray.length == commaDelimitedFieldLabelsArray.length)
			   fieldLabel = commaDelimitedFieldLabelsArray[i];

            fieldLabel = fieldLabel.replace("__r.", "");
            fieldLabel = fieldLabel.replace("__c", "");   
            updatedRLFieldList.push({label: fieldLabel, fieldName: fieldName, type: 'text', sortable : 'true' });  

           }        

        component.set("v.mycolumnsLst",updatedRLFieldList);        
        /******************* END **********************/
                                   
        helper.getDynObjList_WEH(component);   //get the records to be displayed  
		
		/*********************************************/
	    var records = component.get("v.mydataLst");
	    var cardortable = component.get('v.viewType');

		var recCount = component.get("v.mydataLst").length;
	    var colCount = updatedRLFieldList.length;
	    
		if(colCount >= 6 && recCount < 10 && cardortable != 'Table' && cardortable == undefined)
		   component.set('v.viewType','Card');	
		else if(cardortable == undefined)   
		   component.set('v.viewType','Table');	 
		/********************************************/		 
    }
	,
	/**************************************************
	sorting parameters are passed by Lightning with the
	event.
	*************************************************/
    updateColumnSorting: function (cmp, event, helper) 
	    {
        var fieldName = event.getParam('fieldName');
        var sortDirection = event.getParam('sortDirection');
        
		//pass it back to the component
        cmp.set("v.sortedBy", fieldName);
        cmp.set("v.sortedDirection", sortDirection);

        helper.sortData(cmp, fieldName, sortDirection);
        }
})