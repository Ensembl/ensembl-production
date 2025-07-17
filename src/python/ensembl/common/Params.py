#  See the NOTICE file distributed with this work for additional information
#  regarding copyright ownership.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

"""Params module to handle parameter manipulation between pipeline processes."""

import sys
import re
import json
import argparse
import os

from typing import Dict, Any, Optional, Type

sys.tracebacklimit = 0

class Params:
    def __init__(self, params: Optional[Dict[str, Any]] = None, parse_dataflow_json: bool = True) -> None:
        """Params constructor.

        Parameters
        ----------
        params: dict, optional
            The parameters to start the object with. If defined, command-line parameters won't be parsed (default is None)
        parse_dataflow_json: bool, optional
            Specifies whether to parse an option called 'dataflow' in the provided options (default is True)
        """
        self._params = params if params is not None else {}
        if not params:
            self.parse_argv_params(parse_dataflow_json)

    def parse_argv_params(self, parse_dataflow_json: bool = True) -> None:
        """Parses command-line arguments and extracts them into the Params object.
        Command-line arguments need to be passed in the format "--name value".

        Parameters
        ----------
        parse_dataflow_json: bool, optional
            Specifies whether to parse an option called 'dataflow' in the provided options (default is True)
        """
        args = sys.argv[1:]

        # Extract param names from command line
        param_names = [arg for arg in args if arg.startswith("--")]

        parser = argparse.ArgumentParser()
        for name in param_names:
            parser.add_argument(name)

        params = parser.parse_args()
        for param_name in vars(params):
            if param_name == "dataflow" and parse_dataflow_json:
                dataflow_params = json.loads(getattr(params, param_name))
                for name, value in dataflow_params.items():
                    self.set_param(name, value)
            else:
                self.set_param(param_name, getattr(params, param_name))

    def get_param(self, name: str, options: Optional[Dict[str, Any]] = None) -> Any:
        if not name:
            raise AttributeError("You must supply a parameter name")
        if options is None:
            options = {}

        value = self._params.get(name)
        if value is None:
            if "default" in options:
                value = options["default"]
            elif "required" in options and options["required"]:
                raise AttributeError(f"Parameter '{name}' is required but has no value")

        return self.set_param(name, value, options)

    def set_param(self, name: str, value: Any, options: Optional[Dict[str, Any]] = None) -> Any:
        if not name:
            raise AttributeError("You must supply a parameter name")
        if options is None:
            options = {}

        if "type" in options:
            value = self.check_type(name, value, options["type"])

        self._params[name] = value

        return value

    # def param(self, name: str, new_value: Any = None, options: Optional[Dict[str, Any]] = None) -> Any:
    #     """Gets or sets a parameter value.

    #     Parameters
    #     ----------
    #     name: str
    #         The name of the parameter
    #     new_value: any, optional
    #         The value to set the parameter to (default is None)
    #     options: dict, optional
    #         Extra options, including:
    #         - default: The default value to use if parameter has no value (sets the parameter value to this)
    #         - type: The type of the parameter value, used to check if value is valid

    #     Returns
    #     -------
    #     The value of the parameter with provided name.

    #     Raises
    #     ------
    #     AttributeError
    #         If no parameter name was passed.
    #     """
    #     if not name:
    #         raise AttributeError("You must supply a parameter name")
    #     if options is None:
    #         options = {}

    #     if new_value is not None:
    #         self._params[name] = new_value
    #         value = new_value
    #     else:
    #         value = self._params.get(name)
    #         if value is None and "default" in options:
    #             value = options["default"]
    #             self._params[name] = value

    #     if "type" in options:
    #         return self.check_type(name, value, options["type"])

    #     return value

    # def param_required(self, name: str, options: Optional[Dict[str, Any]] = None) -> Any:
    #     """Gets a parameter value, raising an error if no value is found.

    #     Parameters
    #     ----------
    #     name: str
    #         The name of the parameter
    #     options: dict, optional
    #         Extra options, including:
    #         - default: The default value to use if parameter has no value (sets the parameter value to this)
    #         - type: The type of the parameter value, used to check if value is valid

    #     Returns
    #     -------
    #     The value of the parameter with provided name.

    #     Raises
    #     ------
    #     AttributeError
    #         If no value is found for the required parameter.
    #     """
    #     value = self.param(name, None, options)

    #     if value is None:
    #         raise AttributeError(f"Parameter '{name}' is required but has no value")

    #     return value

    def check_type(self, name: str, value: Any, value_type: Type) -> Any:
        """Checks if the parameter value is of the expected type and attempts conversion if necessary.

        Parameters
        ----------
        name: str
            The name of the parameter
        value: Any
            The value of the parameter
        value_type: Type
            The expected type of the parameter (e.g., `int`, `str`, `bool`)

        Returns
        -------
        The value of the parameter with provided name, converted to the correct type if necessary.

        Raises
        ------
        AttributeError
            If the parameter name is missing or the value cannot be converted to the specified type.
        """
        if not name:
            raise AttributeError("You must supply a parameter name")
        if value is None:
            return

        # Special cases first
        if value_type is list:
            if isinstance(value, str):
                # Split the string by commas if present, otherwise wrap it in a list
                value = re.sub(r"\s*,\s*", ",", value)
                value = value.split(",") if "," in value else [value]
            elif not isinstance(value, list):
                # If value is not a list and not a string, raise an error
                raise AttributeError(f"Parameter '{name}' has an invalid value '{value}'. Expected type list")
        elif value_type is bool:
            if isinstance(value, int):
                value = bool(value)
            elif isinstance(value, str):
                if value in ["True", "False"]:
                    value = value == "True"
                elif value in ["0", "1"]:
                    value = bool(int(value))
            elif not isinstance(value, bool):
                raise AttributeError(f"Parameter '{name}' has an invalid value '{value}'. Expected type bool")

        # General type checking for other types
        # if not isinstance(value, value_type):
        try:
            value = value_type(value)  # Attempt conversion
        except (ValueError, TypeError):
            raise AttributeError(f"Parameter '{name}' has an invalid value '{value}'. Expected type {value_type.__name__}")

        return value

    # def check_type(self, name: str, value: Any, value_type: str) -> Any:
    #     """Checks if the parameter value provided is valid.
    #     For specific types, this function can change the parameter value.

    #     Parameters
    #     ----------
    #     name: str
    #         The name of the parameter
    #     value: any
    #         The value of the parameter
    #     value_type: str
    #         The type of the parameter value. Accepted types:
    #         - hash, dict, or dictionary
    #         - array or list
    #         - int or integer
    #         - bool or boolean
    #         - str or string

    #     Returns
    #     -------
    #     None if no value is found, or the new value of the parameter with provided name.

    #     Raises
    #     ------
    #     AttributeError
    #         If no parameter name is provided.
    #         If parameter value is not valid.
    #     """
    #     if not name:
    #         raise AttributeError("You must supply a parameter name")
    #     if value is None:
    #         return

    #     value_type = value_type.lower()
    #     error, update = False, True
    #     new_value = None

    #     if value_type in ["hash", "dict", "dictionary"] and not isinstance(value, dict):
    #         error = True
    #     elif value_type in ["array", "list"] and not isinstance(value, list):
    #         # Try to split by commas
    #         if isinstance(value, str) and "," in value:
    #             new_value = value.split(",")
    #         else:
    #             new_value = [value]
    #     elif value_type in ["int", "integer"] and not isinstance(value, int):
    #         # Try to make it an integer
    #         try:
    #             new_value = int(value)
    #         except ValueError:
    #             error = True
    #     elif value_type in ["bool", "boolean"] and not isinstance(value, bool):
    #         # Try to make it a boolean
    #         if isinstance(value, int):
    #             new_value = bool(value)
    #         elif isinstance(value, str) and value in ["True", "False"]:
    #             new_value = value == "True"
    #         elif value in ["0", "1", 0, 1]:
    #             new_value = bool(int(value))
    #         else:
    #             error = True
    #     elif value_type in ["str", "string"] and not isinstance(value, str):
    #         new_value = str(value)
    #     else:
    #         update = False

    #     if error:
    #         raise AttributeError(
    #             f"Parameter '{name}' has an invalid value '{value}'. Must be of type {value_type}"
    #         )

    #     if update:
    #         self.param(name, new_value)
    #         value = new_value

    #     return value

    def write_output(self, suffix: str, params: Dict[str, Any]) -> None:
        """Appends data to the dataflow json file (passed into next pipeline process).

        Parameters
        ----------
        suffix: str
            The file suffix to add to the output file name (dataflow_[suffix].json)
        params: dict
            The data to append into the file
        """
        # Remove null params
        output_params = {k: v for k, v in params.items() if v is not None}

        dataflow_file = f"dataflow_{suffix}.json"
        dataflow_output_path = self.get_param("dataflow_output_path", {"type": str})
        if dataflow_output_path:
            dataflow_file = os.path.join(dataflow_output_path, dataflow_file)

        with open(dataflow_file, "a") as fh:
            if output_params:
                json.dump(output_params, fh)
                fh.write("\n")
            else:
                fh.write("")

    def write_all_output(self, suffix: str) -> None:
        """Appends all of the parameters in the object into the dataflow json file.
        This calls the write_output function.

        Parameters
        ----------
        suffix: str
            The file suffix to add to the output file name (dataflow_[suffix].json)
        """
        self.write_output(suffix, self._params)
