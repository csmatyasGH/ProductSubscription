/*****************************************
Helper file  to  interact  with apex class
*****************************************/
({
		getBaseUrl : function (component) 
		{
		  var action = component.get('c.getBaseUrl')
		  action.setCallback(this, function (response) 
		  {
			var state = response.getState()
			if (component.isValid() && state === 'SUCCESS') 
			{
			  var result = response.getReturnValue()
			  component.set('v.baseUrl', result)
			}
		  })
		  $A.enqueueAction(action)
		},
		/**************************************
		Read data from the database
		**************************************/
        getDynObjList_WEH : function(component) 
        {
		var updatedRLFieldList = []; 
        //define  action and pass parameter from controller to helper's action method  
		var action = component.get("c.getDynamicObjs");  //getATMs does not  fire yet
		
        action.setParams({ theParentrecID : component.get("v.recordId"), 
                          cols : component.get("v.mycolumnNames"),   
                          ObjName : component.get("v.childObjName"),
                          ParentFieldAPI : component.get("v.LookupFieldName")
                         }) 
         
        action.setCallback(this,function(response) 
            {    
            var state = response.getState(); 
            var result = JSON.stringify(response.getReturnValue()); 
   
            if (component.isValid() && state === "SUCCESS")
               { 
               /**************** START ****************/ 
                var commaDelimitedFieldNames =  component.get("v.mycolumnNames");   
                var commaDelimitedFieldNamesArray = commaDelimitedFieldNames.split(',');
                
				var raw_data = response.getReturnValue();

				var apexError = raw_data.isSuccess;
				if(apexError == false)
				   {				   
				   component.set("v.error",raw_data.message);
				   return;
				   }

                var data = [[]]; 
				data = raw_data.values.DataTable_2D;
			  
				// Go through each response record
                for (var j = 0; j < data.length; j++)      
                {    
                var item = [];
                item = data[j];

                for (var i = 0; i < commaDelimitedFieldNamesArray.length; i++)
                    {
                    var fieldName = commaDelimitedFieldNamesArray[i];                        
					data[j][fieldName] = item[i+1]; 
                    }                            
                }
               /***************** END *****************/         

			   component.set("v.mydataLst",raw_data.values.DataTable_2D);     
               }
               else
               {
			   //include the new error handling features  provided  by ..contr_WEH  
			   component.set("v.error",'some error happened in helper getDynObjs'); 
               }
            }
                          );
        $A.enqueueAction(action);  //only here action fire
        }
		,
		/*************************************************
		this method  was  copy-pasted  from specification.
		try to understand it better
		*************************************************/
		sortData: function (cmp, fieldName, sortDirection) 
		{
			var data = cmp.get("v.mydataLst");
			var reverse = sortDirection !== 'asc';

			/*****************************************
			the below is a method of JavaScript Arrays.
			Array.sort(compareFunction)
			param: compareFunction is optional.
			The compareFunctionfunct. should return a 
			neg. , zero, or pos. value, depending on 
			the arguments.
			*****************************************/
			data.sort(this.sortByMine(fieldName, reverse)) 

			//pass the sorted data back  to component
			cmp.set("v.mydataLst", data);
		}
		,		
		/****************************************
	    Define the compareFunction
		what is the primer?  Where it cames from.
		****************************************/
		sortBy: function (field, reverse, primer) 
		{
			var key = primer ? function(x) 
			                             {
										 return primer(x[field])
										 } 
							   : 
							   function(x) 
										 {
										 return x[field]
									     }
							  ;
			//checks if the two rows should switch places
			reverse = !reverse ? 1 : -1;
			return function (a, b) 
			       {
				   return a = key(a), b = key(b), reverse * ((a > b) - (b > a));
			       }
		}   
		,
		/*******************************************
		rewrite it a bit for my better understanding
		This method is called till swap is required.
		*******************************************/
		sortByMine: function (field, reverse) 
		{
		    //debugger;
		    var key;  
			//key  is a variable of "type" function. 
			//It will be called in a function below.
			key = function(x) 
			      { 
			      return x[field] 
				  }
 
			reverse = !reverse ? 1 : -1; //checks if the two rows should switch places
			
			/*********************
			a, b the items to sort
			is the real comparison
			function.
			*********************/
			return function (a, b) 
			       {
				   var a = key(a);
				   var b = key(b);

				   return reverse * ((a > b) - (b > a));
			       }
		} 		 
})