global class AggregateResultIterable implements Iterable<AggregateResult>
{ 
String aggregateQ;

public AggregateResultIterable(String aq)
{
aggregateQ = aq;
}

public AggregateResultIterable()
{
}

global Iterator<AggregateResult> Iterator()
{ 
 //Iterator<AggregateResult> iteru = new AggregateResultIterator();   
 Iterator<AggregateResult> iteru = new AggregateResultIterator(aggregateQ);  
 System.Debug('CSABAX iteru = ' + iteru); 
return iteru; 
}



}
