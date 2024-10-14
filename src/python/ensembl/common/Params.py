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

from typing import Dict, Any

sys.tracebacklimit = 0


class Params:
    def __init__(self, params: Dict[str, Any] = None, parse_dataflow_json: bool = True) -> None:
        """Params constructor.

        Parameters
        ----------
        params: dict, optional
            The parameters to start the object with. If defined, command-line parameters won't be parsed (default is None)
        parse_dataflow_json: bool, optional
            Specifies whether to parse an option called 'dataflow' in the provided options (default is True)
        """
        if params is None:
            params = {}

        if params:
            self._params = params
        else:
            self._params = {}
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
        r = re.compile(r"^--")
        param_names = list(filter(r.match, args))

        parser = argparse.ArgumentParser()
        for name in param_names:
            parser.add_argument(name)

        params = parser.parse_args()
        for param_name in vars(params):
            if param_name == "dataflow" and parse_dataflow_json:
                dataflow_params = json.loads(getattr(params, param_name))
                for name, value in dataflow_params.items():
                    self.param(name, value)
            else:
                self.param(param_name, getattr(params, param_name))

    def param(self, name: str, new_value: Any = None, options: Dict[str, Any] = None) -> Any:
        """Gets or sets a parameter value.

        Parameters
        ----------
        name: str
            The name of the paramater
        new_value: any, optional
            The value to set the parameter to (default is None)
        options: dict, optional
            Extra options, including:
            - default: The default value to use if parameter has no value (sets the parameter value to this)
            - type: The type of the parameter value, used to check if value is valid

        Returns
        -------
        The value of the parameter with provided name.

        Raises
        ------
        AttributeError
            If no parameter name was passed.
        """
        if not name:
            raise AttributeError("You must supply a parameter name")
        if options is None:
            options = {}

        value = None

        if new_value is not None:
            self._params[name] = new_value
            value = new_value
        else:
            value = self._params.get(name)
            if value is None and options.get("default") is not None:
                default = options["default"]
                self._params[name] = default
                value = default

        if options.get("type"):
            return self.check_type(name, value, options["type"])

        return value

    def param_required(self, name: str, options: Dict[str, Any] = None) -> Any:
        """Gets a parameter value, raising an error if no value is found.

        Parameters
        ----------
        name: str
            The name of th parameter
        options: dict, optional
            Extra options, including:
            - default: The default value to use if parameter has no value (sets the parameter value to this)
            - type: The type of the parameter value, used to check if value is valid

        Returns
        -------
        The value of the parameter with provided name.

        Raises
        ------
        AttributeError
            If no value is found for the required paramater.
        """
        value = self.param(name, None, options)

        if value is None:
            raise AttributeError(f"Parameter '{name}' is required but has no value")

        return value

    def check_type(self, name: str, value: Any, value_type: str) -> Any:
        """Checks if the parameter value provided is valid.
        For specific types, this function can change the parameter value.

        Parameters
        ----------
        name: str
            The name of the parameter
        value: any
            The value of the parameter
        value_type: str
            The type of the parameter value. Accepted types:
            - hash, dict, or dictionary
            - array or list
            - int or integer
            - bool or boolean
            - str or string

        Returns
        -------
        None if no value is found, or the new value of the parameter with provided name.

        Raises
        ------
        AttributeError
            If no parameter name is provided.
            If parameter value is not valid.
        """
        if not name:
            raise AttributeError("You must supply a parameter name")
        if value is None:
            return

        value_type = value_type.lower()
        error, update = False, True
        new_value = None

        if value_type in ["hash", "dict", "dictionary"] and not isinstance(value, dict):
            error = True
        elif value_type in ["array", "list"] and not isinstance(value, list):
            # Try to split by commas
            if re.search(",", value):
                new_value = value.split(",")
            else:
                new_value = [value]
        elif value_type in ["int", "integer"] and not isinstance(value, int):
            # Try to make it an integer
            try:
                new_value = int(value)
            except ValueError:
                error = True
        elif value_type in ["bool", "boolean"] and not isinstance(value, bool):
            # Try to make it a boolean
            if isinstance(value, int):
                new_value = bool(value)
            elif isinstance(value, str) and value in ["True", "False"]:
                new_value = bool(value)
            elif value in ["0", "1", 0, 1]:
                new_value = bool(int(value))
            else:
                error = True
        elif value_type in ["str", "string"] and not isinstance(value, str):
            new_value = str(value)
        else:
            update = False

        if error:
            raise AttributeError(
                f"Parameter '{name}' has an invalid value '{value}'. Must be of type {value_type}"
            )

        if update:
            self.param(name, new_value)
            value = new_value

        return value

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
        params = {k: v for k, v in params.items() if v is not None}

        with open(f"dataflow_{suffix}.json", "a") as fh:
            json.dump(params, fh)
            fh.write("\n")

    def write_all_output(self, suffix: str) -> None:
        """Appends all of the parameters in the object into the dataflow json file.
        This calls the write_output function.

        Parameters
        ----------
        suffix: str
            The file suffix to add to the output file name (dataflow_[suffix].json)
        """
        self.write_output(suffix, self._params)
