package analyzer

import (
	"encoding/json"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"io/fs"
	"path/filepath"
	"strings"
)

// Options configures an analysis run.
type Options struct {
	Path          string
	Exclude       []string
	MaxComplexity int
}

// FileResult holds per-file analysis metrics.
type FileResult struct {
	Path       string `json:"path"`
	Complexity int    `json:"complexity"`
	Lines      int    `json:"lines"`
}

// Result aggregates the outcome of an analysis run.
type Result struct {
	Files    []*FileResult `json:"files"`
	Warnings []string      `json:"warnings"`
}

// Print writes a summary of the result to stdout in the requested format.
func (r *Result) Print(format string) error {
	switch format {
	case "json":
		enc := json.NewEncoder(fmt.Errorf("").(*fmt.Stringer)(nil)) // placeholder
		_ = enc
		b, _ := json.MarshalIndent(r, "", "  ")
		fmt.Println(string(b))
	default:
		fmt.Printf("%-40s %10s %6s\n", "FILE", "COMPLEXITY", "LINES")
		for _, f := range r.Files {
			fmt.Printf("%-40s %10d %6d\n", f.Path, f.Complexity, f.Lines)
		}
	}
	return nil
}

// Render produces a string report in the given format.
func (r *Result) Render(format string) (string, error) {
	var sb strings.Builder
	switch format {
	case "html":
		sb.WriteString("<html><body><table>\n")
		for _, f := range r.Files {
			fmt.Fprintf(&sb, "<tr><td>%s</td><td>%d</td><td>%d</td></tr>\n",
				f.Path, f.Complexity, f.Lines)
		}
		sb.WriteString("</table></body></html>\n")
	default: // markdown
		sb.WriteString("| File | Complexity | Lines |\n")
		sb.WriteString("|------|-----------|-------|\n")
		for _, f := range r.Files {
			fmt.Fprintf(&sb, "| %s | %d | %d |\n", f.Path, f.Complexity, f.Lines)
		}
	}
	return sb.String(), nil
}

// Analyzer performs static analysis on a Go source tree.
type Analyzer struct {
	opts Options
}

// New creates a new Analyzer with the given options.
func New(opts Options) *Analyzer {
	return &Analyzer{opts: opts}
}

// Run walks the source tree and returns aggregated analysis results.
func (a *Analyzer) Run() (*Result, error) {
	fset := token.NewFileSet()
	result := &Result{}

	err := filepath.WalkDir(a.opts.Path, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || !strings.HasSuffix(path, ".go") {
			return nil
		}
		for _, pattern := range a.opts.Exclude {
			if matched, _ := filepath.Match(pattern, filepath.Base(path)); matched {
				return nil
			}
		}

		file, err := parser.ParseFile(fset, path, nil, 0)
		if err != nil {
			result.Warnings = append(result.Warnings, fmt.Sprintf("parse error in %s: %v", path, err))
			return nil
		}

		complexity := computeComplexity(file)
		lines := fset.File(file.Pos()).LineCount()

		fr := &FileResult{
			Path:       path,
			Complexity: complexity,
			Lines:      lines,
		}
		result.Files = append(result.Files, fr)

		if a.opts.MaxComplexity > 0 && complexity > a.opts.MaxComplexity {
			result.Warnings = append(result.Warnings,
				fmt.Sprintf("%s: complexity %d exceeds threshold %d", path, complexity, a.opts.MaxComplexity))
		}

		return nil
	})

	return result, err
}

// computeComplexity calculates a rough cyclomatic complexity for an AST file.
func computeComplexity(f *ast.File) int {
	count := 1
	ast.Inspect(f, func(n ast.Node) bool {
		switch n.(type) {
		case *ast.IfStmt, *ast.ForStmt, *ast.RangeStmt,
			*ast.CaseClause, *ast.CommClause, *ast.SelectStmt:
			count++
		}
		return true
	})
	return count
}
