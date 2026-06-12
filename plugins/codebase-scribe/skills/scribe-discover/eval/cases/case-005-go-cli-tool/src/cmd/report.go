package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/example/codeanalyzer/internal/analyzer"
)

var reportCmd = &cobra.Command{
	Use:   "report [path]",
	Short: "Generate a full HTML or Markdown report for a Go source tree",
	Args:  cobra.ExactArgs(1),
	RunE:  runReport,
}

func init() {
	reportCmd.Flags().StringP("format", "f", "markdown", "Report format: markdown, html")
	reportCmd.Flags().StringP("dest", "d", "report.md", "Destination file for the report")
}

func runReport(cmd *cobra.Command, args []string) error {
	path := args[0]
	format, _ := cmd.Flags().GetString("format")
	dest, _ := cmd.Flags().GetString("dest")
	outputFmt, _ := cmd.Root().PersistentFlags().GetString("output")

	a := analyzer.New(analyzer.Options{Path: path})
	result, err := a.Run()
	if err != nil {
		return fmt.Errorf("analysis failed: %w", err)
	}

	content, err := result.Render(format)
	if err != nil {
		return fmt.Errorf("render failed: %w", err)
	}

	if err := os.WriteFile(dest, []byte(content), 0o644); err != nil {
		return fmt.Errorf("could not write report to %s: %w", dest, err)
	}

	if outputFmt != "json" {
		fmt.Printf("Report written to %s\n", dest)
	}
	return nil
}
