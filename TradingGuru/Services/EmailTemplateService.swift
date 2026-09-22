//
//  EmailTemplateService.swift
//  TradingGuru
//
//  Service for generating email templates for analysis results notifications.
//

import Foundation

// MARK: - Email Notification Model

/// Model representing an email notification with analysis results.
/// - Validates: Requirement 9.4 (Email content format)
struct EmailNotification: Equatable {
    /// The recipient email address
    let recipient: String
    
    /// The email subject line
    /// Format: "TradingGuru Analysis Results - [Date] [Time] PST"
    let subject: String
    
    /// The HTML body content of the email
    let htmlBody: String
    
    /// Count of CALL opportunities in the results
    let callCount: Int
    
    /// Count of PUT opportunities in the results
    let putCount: Int
}

// MARK: - Email Template Service

/// Service for generating email templates for analysis results.
/// - Validates: Requirements 9.4, 9.5, 9.6
enum EmailTemplateService {
    
    // MARK: - Constants
    
    /// Background color for ORDER signal rows (light green)
    /// - Validates: Requirement 9.5 (ORDER rows highlighted with distinct background color)
    private static let orderRowBackgroundColor = "#E8F5E9"
    
    /// Default row background color
    private static let defaultRowBackgroundColor = "#FFFFFF"
    
    /// Alternate row background color for non-ORDER rows
    private static let alternateRowBackgroundColor = "#F5F5F5"
    
    /// Color for earnings dates with risk (red)
    /// - Validates: Requirement 9.6 (Earnings dates in red when hasEarningsRisk=true)
    private static let earningsRiskColor = "#FF0000"
    
    /// Default text color
    private static let defaultTextColor = "#333333"
    
    /// Header background color
    private static let headerBackgroundColor = "#2196F3"
    
    /// Header text color
    private static let headerTextColor = "#FFFFFF"
    
    // MARK: - Subject Line Generation
    
    /// Generates the email subject line with current date and time in PST.
    /// - Parameter date: The date to use for the subject line (defaults to current date)
    /// - Returns: Formatted subject line
    /// - Validates: Requirement 9.4 (Subject line "TradingGuru Analysis Results - [Date] [Time] PST")
    static func generateSubjectLine(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        let dateTimeString = formatter.string(from: date)
        return "TradingGuru Analysis Results - \(dateTimeString) PST"
    }
    
    // MARK: - HTML Table Generation
    
    /// Generates an HTML table from analysis results.
    /// - Parameter results: The analysis results to include in the table
    /// - Returns: HTML string containing the formatted table
    /// - Validates: Requirements 9.4, 9.5, 9.6 (HTML table with highlighting and styling)
    static func generateHTMLTable(results: [AnalysisResult]) -> String {
        var html = """
        <table style="border-collapse: collapse; width: 100%; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size: 14px;">
            <thead>
                <tr style="background-color: \(headerBackgroundColor); color: \(headerTextColor);">
                    <th style="padding: 12px 8px; text-align: left; border: 1px solid #ddd;">Ticker</th>
                    <th style="padding: 12px 8px; text-align: left; border: 1px solid #ddd;">Type</th>
                    <th style="padding: 12px 8px; text-align: right; border: 1px solid #ddd;">Return %</th>
                    <th style="padding: 12px 8px; text-align: right; border: 1px solid #ddd;">Current Price</th>
                    <th style="padding: 12px 8px; text-align: right; border: 1px solid #ddd;">Target Price</th>
                    <th style="padding: 12px 8px; text-align: center; border: 1px solid #ddd;">Signal</th>
                    <th style="padding: 12px 8px; text-align: center; border: 1px solid #ddd;">Next Earnings Date</th>
                </tr>
            </thead>
            <tbody>
        """
        
        for (index, result) in results.enumerated() {
            let rowHtml = generateTableRow(result: result, index: index)
            html += rowHtml
        }
        
        html += """
            </tbody>
        </table>
        """
        
        return html
    }
    
    /// Generates a single table row for an analysis result.
    /// - Parameters:
    ///   - result: The analysis result
    ///   - index: The row index (for alternate row coloring)
    /// - Returns: HTML string for the table row
    private static func generateTableRow(result: AnalysisResult, index: Int) -> String {
        // Determine background color based on signal
        // - Validates: Requirement 9.5 (ORDER rows highlighted with distinct background color)
        let backgroundColor: String
        if result.signal == .order {
            backgroundColor = orderRowBackgroundColor
        } else {
            backgroundColor = index % 2 == 0 ? defaultRowBackgroundColor : alternateRowBackgroundColor
        }
        
        // Format values
        let tickerDisplay = result.ticker
        let typeDisplay = result.type.rawValue
        let returnDisplay = formatReturnPercentage(result.returnPercentage)
        let currentPriceDisplay = formatCurrency(result.currentPrice)
        let targetPriceDisplay = formatCurrency(result.targetPrice)
        let signalDisplay = result.signal.rawValue
        let earningsDateDisplay = formatEarningsDate(result.nextEarningsDate, hasRisk: result.hasEarningsRisk)
        
        return """
                <tr style="background-color: \(backgroundColor);">
                    <td style="padding: 10px 8px; border: 1px solid #ddd; font-weight: 600;">\(tickerDisplay)</td>
                    <td style="padding: 10px 8px; border: 1px solid #ddd;">\(typeDisplay)</td>
                    <td style="padding: 10px 8px; border: 1px solid #ddd; text-align: right;">\(returnDisplay)</td>
                    <td style="padding: 10px 8px; border: 1px solid #ddd; text-align: right;">\(currentPriceDisplay)</td>
                    <td style="padding: 10px 8px; border: 1px solid #ddd; text-align: right;">\(targetPriceDisplay)</td>
                    <td style="padding: 10px 8px; border: 1px solid #ddd; text-align: center; font-weight: 600;">\(signalDisplay)</td>
                    <td style="padding: 10px 8px; border: 1px solid #ddd; text-align: center;">\(earningsDateDisplay)</td>
                </tr>
        """
    }
    
    // MARK: - Summary Generation
    
    /// Generates a summary section with CALL and PUT counts.
    /// - Parameter results: The analysis results to summarize
    /// - Returns: HTML string containing the summary
    /// - Validates: Requirement 9.4 (Summary with CALL/PUT counts)
    static func generateSummary(results: [AnalysisResult]) -> String {
        let callCount = results.filter { $0.type == .call }.count
        let putCount = results.filter { $0.type == .put }.count
        let totalCount = results.count
        let orderCount = results.filter { $0.signal == .order }.count
        
        return """
        <div style="margin-top: 20px; padding: 15px; background-color: #F5F5F5; border-radius: 8px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
            <h3 style="margin: 0 0 10px 0; color: #333333; font-size: 16px;">Summary</h3>
            <p style="margin: 5px 0; color: #555555; font-size: 14px;">
                <strong>Total Opportunities:</strong> \(totalCount)
            </p>
            <p style="margin: 5px 0; color: #555555; font-size: 14px;">
                <strong>CALL Opportunities:</strong> \(callCount)
            </p>
            <p style="margin: 5px 0; color: #555555; font-size: 14px;">
                <strong>PUT Opportunities:</strong> \(putCount)
            </p>
            <p style="margin: 5px 0; color: #555555; font-size: 14px;">
                <strong>ORDER Signals:</strong> \(orderCount)
            </p>
        </div>
        """
    }
    
    // MARK: - Full Email Generation
    
    /// Generates a complete email notification from analysis results.
    /// - Parameters:
    ///   - results: The analysis results to include
    ///   - recipient: The recipient email address
    ///   - date: The date for the subject line (defaults to current date)
    /// - Returns: A complete EmailNotification
    /// - Validates: Requirements 9.4, 9.5, 9.6 (Complete email content)
    static func generateEmailNotification(
        results: [AnalysisResult],
        recipient: String,
        date: Date = Date()
    ) -> EmailNotification {
        let subject = generateSubjectLine(for: date)
        let htmlBody = generateFullHTMLBody(results: results, date: date)
        let callCount = results.filter { $0.type == .call }.count
        let putCount = results.filter { $0.type == .put }.count
        
        return EmailNotification(
            recipient: recipient,
            subject: subject,
            htmlBody: htmlBody,
            callCount: callCount,
            putCount: putCount
        )
    }
    
    /// Generates the full HTML body for the email.
    /// - Parameters:
    ///   - results: The analysis results
    ///   - date: The date of the analysis
    /// - Returns: Complete HTML document string
    private static func generateFullHTMLBody(results: [AnalysisResult], date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        let dateTimeString = formatter.string(from: date)
        
        let table = generateHTMLTable(results: results)
        let summary = generateSummary(results: results)
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>TradingGuru Analysis Results</title>
        </head>
        <body style="margin: 0; padding: 20px; background-color: #f0f0f0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
            <div style="max-width: 800px; margin: 0 auto; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                <div style="background-color: \(headerBackgroundColor); padding: 20px; text-align: center;">
                    <h1 style="margin: 0; color: \(headerTextColor); font-size: 24px;">TradingGuru Analysis Results</h1>
                    <p style="margin: 10px 0 0 0; color: rgba(255,255,255,0.9); font-size: 14px;">\(dateTimeString) PST</p>
                </div>
                <div style="padding: 20px;">
                    <div style="overflow-x: auto;">
                        \(table)
                    </div>
                    \(summary)
                    <div style="margin-top: 20px; padding-top: 15px; border-top: 1px solid #eee; text-align: center;">
                        <p style="margin: 0; color: #888888; font-size: 12px;">
                            This email was generated automatically by TradingGuru.
                        </p>
                        <p style="margin: 5px 0 0 0; color: #888888; font-size: 12px;">
                            <span style="color: \(orderRowBackgroundColor); background-color: \(orderRowBackgroundColor);">■</span> = ORDER signal row &nbsp;|&nbsp;
                            <span style="color: \(earningsRiskColor);">■</span> = Earnings risk (date on or before expiration)
                        </p>
                    </div>
                </div>
            </div>
        </body>
        </html>
        """
    }
    
    // MARK: - Formatting Helpers
    
    /// Formats a return percentage to 2 decimal places with % symbol.
    /// - Parameter value: The return percentage value
    /// - Returns: Formatted string (e.g., "+12.34%" or "-5.67%")
    private static func formatReturnPercentage(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", prefix, value)
    }
    
    /// Formats a price as currency with 2 decimal places.
    /// - Parameter value: The price value
    /// - Returns: Formatted currency string (e.g., "$123.45")
    private static func formatCurrency(_ value: Double) -> String {
        return String(format: "$%.2f", value)
    }
    
    /// Formats an earnings date with optional red color for risk.
    /// - Parameters:
    ///   - date: The optional earnings date
    ///   - hasRisk: Whether the earnings date has risk
    /// - Returns: HTML string with formatted date
    /// - Validates: Requirement 9.6 (Earnings dates in red when hasEarningsRisk=true)
    private static func formatEarningsDate(_ date: Date?, hasRisk: Bool) -> String {
        guard let date = date else {
            return "N/A"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = formatter.string(from: date)
        
        if hasRisk {
            return "<span style=\"color: \(earningsRiskColor); font-weight: 600;\">\(dateString)</span>"
        } else {
            return dateString
        }
    }
}
