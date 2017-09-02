# Contributing to Llvm.NET
One of the easiest ways to contribute is to participate in discussions and discuss issues. You can also contribute by
submitting pull requests with code changes. This project has adopted the code of conduct defined by the 
[Contributor Covenant](http://contributor-covenant.org/) to clarify expected behavior in our community.
For more information see the [.NET Foundation Code of Conduct](http://www.dotnetfoundation.org/code-of-conduct).

## General feedback and discussions?
Please start a discussion in the [project issue tracker](https://github.com/netmf/Llvm.NET/issues).

## Filing Bugs
The best way to get your bug fixed is to be as detailed as you can be about the problem.
Providing a minimal project with steps to reproduce the problem is ideal.
Here are questions you can answer before you file a bug to make sure you're not missing any important information.

1. Did you include the snippet of broken code in the issue?
2. What are the *EXACT* steps to reproduce this problem?

GitHub supports [markdown](https://guides.github.com/features/mastering-markdown/), so when filing bugs make sure you
check the formatting before clicking submit.

## Contributing code and content
Make sure you can build the code. Familiarize yourself with the project workflow and our coding conventions. If you don't
know what a pull request is read this article: https://help.github.com/articles/using-pull-requests.

Before submitting a feature or substantial code contribution please discuss it with the team and ensure it follows the
product roadmap. Get buy in on the need for the change before even thinking about making it. 

If you haven't already, please readn read these two blogs posts on contributing code:
[Open Source Contribution Etiquette](http://tirania.org/blog/archive/2010/Dec-31.html) by Miguel de Icaza
and [Don't "Push" Your Pull Requests](http://www.igvita.com/2011/12/19/dont-push-your-pull-requests/) by Ilya Grigorik.
Understanding and following the guidance in these articles will go a long way to keeping things calm and smoothly flowing.

Note that all code submissions must be reviewed and tested. Only those that meeet the high bar for both quality and
design/roadmap appropriateness will be merged into the source.

**Tests**
-  Tests should be provided for every bug/feature that is completed.
-  Tests only need to be present for issues that need to be verified by QA (e.g. not tasks, docs or build infrastructure)
-  If there is a scenario that is far too hard to test there does not need to be a test for it.
  - "Too hard" is determined by the team as a whole.
