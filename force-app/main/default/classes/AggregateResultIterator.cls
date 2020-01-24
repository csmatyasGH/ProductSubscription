global class AggregateResultIterator Implements Iterator<AggregateResult>{ 

AggregateResult [] results {get;set;} 
Integer index {get;set;} 

global AggregateResultIterator()
{ 
String query = 'select Id, MIN(createdDate) from Account GROUP BY Id LIMIT 100'; 
results = Database.query(query); 
System.Debug('CSABAX default result size = ' +  results.size());
} 

global AggregateResultIterator(String aggregateQuery)
{
System.Debug('CSABAX aggregateQuery = ' + aggregateQuery);
results = Database.query(aggregateQuery); 
System.Debug('CSABAX aggregateQ result size = ' +  results.size());
} 

global boolean hasNext()
{ 
return results !=null && !results.isEmpty() && index < results.size(); 
} 

global AggregateResult next()
{ 
return results[index++]; 
} 
}