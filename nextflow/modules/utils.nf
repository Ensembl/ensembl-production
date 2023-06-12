def checkParams(allowedParams) {    

    /*
      Function: checkParams
      Description: Checks the params defined by the user.
      Input: inputData - allowedParams (list of params allowed for a pipeline])
      Output: result - Throws the exception . (Type: RuntimeException])
    */

    unknownParams = params.keySet() - allowedParams
    if (unknownParams) {
        throw new RuntimeException("Unknown parameters: ${unknownParams.join(', ')}")
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