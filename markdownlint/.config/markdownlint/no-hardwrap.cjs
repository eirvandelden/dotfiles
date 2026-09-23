"use strict";

// A wrapped paragraph is one micromark splits into several source lines with a soft line
// ending (a plain newline), as opposed to a hard line break (`hardBreakEscape`/
// `hardBreakTrailing`). Reports every paragraph token at any depth, so paragraphs inside list
// items and block quotes are covered without separate handling.

const HARD_LINE_ENDING_TYPES = new Set([ "hardBreakEscape", "hardBreakTrailing" ]);
const NOT_LINE_TEXT_TYPES = new Set([ "lineEnding", "linePrefix", "listItemIndent", "blockQuotePrefix", "whitespace" ]);

function collectParagraphs(tokens, found) {
  for (const token of tokens) {
    if (token.type === "paragraph") {
      found.push(token);
    }
    collectParagraphs(token.children, found);
  }
  return found;
}

// The paragraph's text tokens at every depth, leaving out prefixes and their own children (a
// block quote's `>` marker sits inside its prefix token).
function textTokensOf(token, found = []) {
  for (const child of token.children) {
    if (NOT_LINE_TEXT_TYPES.has(child.type)) {
      continue;
    }
    found.push(child);
    textTokensOf(child, found);
  }
  return found;
}

// A line ending counts as soft unless a hard line break sits right before it in the same parent;
// looking at every depth catches a wrap inside emphasis, a link label or a code span.
function softLinesAfter(token, lines = new Set()) {
  token.children.forEach((child, index) => {
    const previous = token.children[index - 1];
    if (child.type === "lineEnding" && !(previous && HARD_LINE_ENDING_TYPES.has(previous.type))) {
      lines.add(child.endLine);
    }
    softLinesAfter(child, lines);
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
  return runs.filter((lines) => lines.length > 1);
}

// Everything on the line from where the paragraph's text starts, so list indentation and a block
// quote prefix drop but no inline markup does.
function textOnLine(textTokens, line, sourceLine) {
  const columns = textTokens
    .filter((token) => token.startLine === line)
    .map((token) => token.startColumn);
  return columns.length > 0 ? sourceLine.slice(Math.min(...columns) - 1) : "";
}

// Trailing whitespace inside a run is dropped, but the run's last line keeps its own: two
// trailing spaces there are the hard line break that ended the run.
function joinedContinuation(continuationLines, textTokens, params) {
  const lastLine = continuationLines[continuationLines.length - 1];
  return continuationLines
    .map((line) => {
      const text = textOnLine(textTokens, line, params.lines[line - 1]);
      return line === lastLine ? text : text.trimEnd();
    })
    .join(" ");
}

function detailFor(run) {
  return `join lines ${run[0]}–${run[run.length - 1]} into one line`;
}

function reportParagraph(paragraph, onError) {
  for (const run of runsIn(paragraph)) {
    onError({ lineNumber: run[0], detail: detailFor(run) });
  }
}

function unwrapParagraph(paragraph, params, onError) {
  const textTokens = textTokensOf(paragraph);

  for (const run of runsIn(paragraph)) {
    const [ firstLine, ...continuationLines ] = run;
    const detail = detailFor(run);
    const continuationText = joinedContinuation(continuationLines, textTokens, params);
    const firstSource = params.lines[firstLine - 1];
    const firstText = firstSource.trimEnd();

    onError({
      lineNumber: firstLine,
      detail,
      fixInfo: {
        editColumn: firstText.length + 1,
        deleteCount: firstSource.length - firstText.length,
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
