
# Gallery

SQLPlusX provides color feedback for incomplete transactions based on the row count.
When (and only when) one row is affected, this shows the feedback as green.  If over
one hundred rows are affected, the feedback row flashes red.

![during-transaction](./images/gallery/during-transaction.png)

After commit the rows become the regular text color to indicate they are now a permanent
part of the history.  If a rollback occurs, they become grey.

![after-rollback](./images/gallery/after-rollback.png)

SQLPlusX has auto complete on internal commands.

![Autocomplete Commands](./images/gallery/autocomplete-commands.png)
![Autocomplete Package Members](./images/gallery/autocomplete-package-members.png)
![Autocomplete Set 1](./images/gallery/autocomplete-set-1.png)
![Autocomplete Set 2](./images/gallery/autocomplete-set-2.png)

Autocomplete includes tables and columns in SQL.

![Autocomplete Tables](./images/gallery/autocomplete-tables.png)
![Autocomplete Columns](./images/gallery/autocomplete-columns.png)

SQLPlusX emulates the look and feel of a command line, but is actually rendered on live data.
This means columns can dynamically size according to the available space.

![Dynamic Columns Autofit](./images/gallery/autofit-columns.gif)

SQLPlusX supports CLOB fields.  If a CLOB column is in the SELECT list, its contents are 
downloaded for you.

![CLOB Support](./images/gallery/clob-support.png)

If the data is truncated for the screen (CLOB or otherwise), the source can still be seen on rollover.

![Rollover 1](./images/gallery/rollover-1.png)
![Rollover 2](./images/gallery/rollover-2.png)

All queries are executed on a worker thread, leaving the UI free and never blocking your workflow.
If a long running query is in progress you can cancel at any time with Escape or type in a follow 
up statement.  These build up in a command queue.

![Command Queue](./images/gallery/command-queue.png)

Describe package applies syntax highlighting.

![Describe Package](./images/gallery/describe-package.png)

Describe has also been enhanced to support some other object types.

![Describe Index](./images/gallery/describe-index.png)
![Describe Sequence](./images/gallery/describe-sequence.png)

Describe table shows comments.

![Describe Table](./images/gallery/describe-table.png)

Execute and PL/SQL work as expected.

![Execute Command](./images/gallery/execute-command.png)

The Host command directs the output into the buffer.

![Host Command](./images/gallery/host-command.png)

Show all includes new client settings as well as old backwards compatible options.

![Show All 1](./images/gallery/show-all-1.png)
![Show All 2](./images/gallery/show-all-2.png)

Error messages provide the surrounding context and highlight the problem area.

![Highlighted](./images/gallery/highlighted-errors.png)

If the failing statement is from a script file, the line number is correctly calculated for you.

![Highlighted](./images/gallery/highlighted-errors-script.png)

The new Source command provides syntax highlighted output on packages and views.

![Source Package](./images/gallery/source-package.png)
![Source View](./images/gallery/source-view.png)




