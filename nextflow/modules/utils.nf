def requiredParams(requiredParamsList) {

    /*
      Function: requiredParamsList
      Description: Checks the required params defined by the user.
      Input: inputData - None (default nextflow params Type: None)
      Output: result - Throws the exception . (Type: RuntimeException])
    */

     
    if (! params.keySet().containsAll(requiredParams)) {
        throw new RuntimeException("Missing required parameters : ${requiredParams.join(', ')}")
    }
}


def convertToList( userParam ){

    /*
      Function: convertToList
      Description: Convert User defined comma seperated params into a list.
      Input: inputData - Comma seperated string. (Type: String, Ex: "homo_sapiens,mus_musculus")
      Output: result - Split the string with delimitar. (Type: List[String])
    */ 

    if ( userParam && userParam != true && userParam != false){
        return userParam.split(',').collect { value -> "\"$value\""}
    }

    return []	

}