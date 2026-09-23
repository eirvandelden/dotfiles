"use strict";

// A wrapped paragraph is one micromark splits into several source lines with a soft line
// ending (a plain newline), as opposed to a hard line break (`hardBreakEscape`/
// `hardBreakTrailing`). Reports every paragraph token at any depth, so paragraphs inside list
// items and block quotes are covered without separate handling.

const HARD_LINE_ENDING_TYPES = new Set([ "hardBreakEscape", "hardBreakTrailing" ]);
const INDENT_OR_PREFIX_TYPES = new Set([ "listItemIndent", "blockQuotePrefix" ]);

function collectParagraphs(tokens, found) {
  for (const token of tokens) {
    if (token.type === "paragraph") {
      found.push(token);
    }
    collectParagraphs(token.children, found);
  }
  return found;
}

function softLineEndingAt(children, index) {
  const previous = children[index - 1];
  return !previous || !HARD_LINE_ENDING_TYPES.has(previous.type);
}

function isWrapped(paragraph) {
  const children = paragraph.children;
  return children.some((child, index) => child.type === "lineEnding" && softLineEndingAt(children, index));
}

function softLinesAfter(paragraph) {
  const children = paragraph.children;
  const lines = new Set();
  children.forEach((child, index) => {
    if (child.type === "lineEnding" && softLineEndingAt(children, index)) {
      lines.add(child.endLine);
    }
  });
  return lines;
}

// Splits a paragraph's lines into runs joined by soft line endings; a hard line break starts a
// new run, since that line break was intentional rather than a wrap to undo.
function runsIn(paragraph) {
  const softAfter = softLinesAfter(paragraph);
  const runs = [];
  let run = [ paragraph.startLine ];
  for (let line = paragraph.startLine + 1; line <= paragraph.endLine; line += 1) {
    if (softAfter.has(line)) {
      run.push(line);
    } else {
      runs.push(run);
      run = [ line ];
    }
  }
  runs.push(run);
  return runs;
}

// The line's own text, dropping any list indentation or block quote prefix that precedes it.
function textOnLine(paragraph, lineNumber) {
  const token = paragraph.children.find(
    (child) => child.startLine === lineNumber && !INDENT_OR_PREFIX_TYPES.has(child.type)
  );
  return token ? token.text : "";
}

function reportParagraph(paragraph, onError) {
  if (!isWrapped(paragraph)) {
    return;
  }

  onError({
    lineNumber: paragraph.startLine,
    detail: `join lines ${paragraph.startLine}–${paragraph.endLine} into one line`
  });
}

function unwrapParagraph(paragraph, params, onError) {
  for (const run of runsIn(paragraph)) {
    if (run.length < 2) {
      continue;
    }

    const [ firstLine, ...continuationLines ] = run;
    const lastLine = run[run.length - 1];
    const detail = `join lines ${firstLine}–${lastLine} into one line`;
    const continuationText = continuationLines.map((line) => textOnLine(paragraph, line)).join(" ");

    onError({
      lineNumber: firstLine,
      detail,
      fixInfo: {
        editColumn: params.lines[firstLine - 1].length + 1,
        insertText: ` ${continuationText}`
      }
    });

    for (const line of continuationLines) {
      onError({ lineNumber: line, detail, fixInfo: { deleteCount: -1 } });
    }
  }
}

module.exports = {
  names: [ "no-hardwrap" ],
  description: "Reports a paragraph split across soft-wrapped source lines",
  tags: [ "markdown" ],
  parser: "micromark",
  function: (params, onError) => {
    const paragraphs = collectParagraphs(params.parsers.micromark.tokens, []);
    const unwrap = Boolean(params.config && params.config.unwrap);

    for (const paragraph of paragraphs) {
      if (unwrap) {
        unwrapParagraph(paragraph, params, onError);
      } else {
        reportParagraph(paragraph, onError);
      }
    }
  }
};
