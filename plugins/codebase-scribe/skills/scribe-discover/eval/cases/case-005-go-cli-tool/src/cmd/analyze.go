package cmd

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/example/codeanalyzer/internal/analyzer"
)

var analyzeCmd = &cobra.Command{
	Use:   "analyze [path]",
	Short: "Analyze a Go source tree",
	Args:  cobra.ExactArgs(1),
	RunE:  runAnalyze,
}

func init() {
	analyzeCmd.Flags().StringSliceP("exclude", "e", nil, "Patterns to exclude from analysis")
	analyzeCmd.Flags().IntP("max-complexity", "c", 10, "Maximum cyclomatic complexity threshold")
}

func runAnalyze(cmd *cobra.Command, args []string) error {
	path := args[0]
	exclude, _ := cmd.Flags().GetStringSlice("exclude")
	maxComplexity, _ := cmd.Flags().GetInt("max-complexity")
	outputFmt, _ := cmd.Root().PersistentFlags().GetString("output")

	a := analyzer.New(analyzer.Options{
		Path:          path,
		Exclude:       exclude,
		MaxComplexity: maxComplexity,
	})

	result, err := a.Run()
	if err != nil {
		return fmt.Errorf("analysis failed: %w", err)
	}

	return result.Print(outputFmt)
}
