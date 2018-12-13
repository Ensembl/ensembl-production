**Any pull request that does not include enough information to be reviewed in a timely manner may be closed at the maintainers' discretion**

## Requirements

- Filling out the template is required. 
- Review the [contributing guidelines](https://github.com/Ensembl/ensembl/blob/master/CONTRIBUTING.md#why-could-my-pull-request-be-rejected) for this repository; remember in particular:
    - do not modify code without testing for regression
    - provide simple unit tests to test the changes
    - if you change the schema you must patch the test databases as well, see [Updating the schema](https://github.com/Ensembl/ensembl/blob/master/CONTRIBUTING.md#updating-the-schema)
    - the PR must not fail unit testing

## Description

_Using one or more sentences, describe in detail the proposed changes._

## Use case

_Describe the problem. Please provide an example representing the motivation behind the need for having these changes in place._

## Benefits

_If applicable, describe the advantages the changes will have._

## Possible Drawbacks

_If applicable, describe any possible undesirable consequence of the changes._

## Testing

- [ ] Have you added/modified unit tests to test the changes?
- [ ] If so, do the tests pass?
- [ ] Have you run the entire test suite and no regression was detected?
- [ ] TravisCI passed on your branch

Dependencies
------------

> If applicable, define what code dependencies were added and/or updated.
