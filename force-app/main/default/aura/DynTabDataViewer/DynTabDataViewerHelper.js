({
	getSetupData_WEH : function(component) 
    {
	    //debugger; 
        var action = component.get("c.getSetupObjRecords");  
        action.setParams({ 
                           DestinationRecordID : component.get("v.DestinationRecord_ID")
                         }) 

        action.setCallback(this,function(response) 
            {
            var state = response.getState(); //Checking response status
			//debugger;
            var result = JSON.stringify(response.getReturnValue()); 
 
            if (component.isValid() && state === "SUCCESS")
               {
			    var raw_resp = response.getReturnValue();

				var apexError = raw_resp.isSuccess;  
				if(apexError == true)
				{
					var Setup_Data = raw_resp.values.setupData;

					var multi = Setup_Data.length; 
					if(multi > 1)
					   component.set("v.Needtab",true);
					else
					   component.set("v.Needtab",false); 
				
					component.set("v.mySetupdata",Setup_Data);
				}
				else
				{
					component.set("v.error",raw_resp.message);
				}
 
               }// end if component.isValid() && state === "SUCCESS"
            else
               {  
				component.set("v.error",'We have error during GetSetupData. ' + state); 
               }
            }//end calllback
                          );
        $A.enqueueAction(action);  //only here action fire??
    }

})