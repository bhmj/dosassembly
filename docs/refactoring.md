## Issues
    + random '\r' in server output

## Refactoring
    + move ace cursor to 0:0
    + fix dark theme
    + store theme name in local storage
    + add DB support
      + tables
        + sources: SRCID, txt, asm type
        + examples: filename, image filename, size category, asm type, description, link, rating
      + SPs: store source
    + store support
      + add UI button
      + generate handler
      + save in DB
      + update URL in address line
      ? versioning
    + load support
      + index.html in template
      + read handler
      + read source data
      + output
    + examples
      + template
      + filters: size category
      ? search by description
    + documentation
      + inner navigation <- (home) ->
      + sources

