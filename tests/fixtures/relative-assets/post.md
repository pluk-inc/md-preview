# Quick Look relative-asset fixture

This file exercises the four cases the QL preview must handle:

## Sibling file in subfolder

![local](images/local.png)

## Sibling file with URL-encoded spaces

![spaces](images%20dir/two%20words.png)

## Absolute http URL (must keep working)

![remote](https://www.apple.com/ac/structured-data/images/knowledge_graph_logo.png?202210171354)

## Missing file (broken-image is acceptable, no crash)

![missing](images/missing.png)
