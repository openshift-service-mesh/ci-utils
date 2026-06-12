package cmd

import (
	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "codeanalyzer",
	Short: "A static analysis tool for Go codebases",
	Long: `codeanalyzer inspects Go source trees and produces structured reports
about code complexity, dependency health, and test coverage.`,
}

// Execute runs the root command and returns any error.
func Execute() error {
	return rootCmd.Execute()
}

func init() {
	rootCmd.PersistentFlags().StringP("output", "o", "table", "Output format: table, json, yaml")
	rootCmd.PersistentFlags().BoolP("verbose", "v", false, "Enable verbose output")

	rootCmd.AddCommand(analyzeCmd)
	rootCmd.AddCommand(reportCmd)
}
