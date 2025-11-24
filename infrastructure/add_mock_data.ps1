# PowerShell script to add mock data to TicketSync-Tickets DynamoDB table

$mockTickets = @(
    @{
        ticket_id = "TICKET-001"
        timestamp = "2025-01-15T10:00:00"
        status = "OPEN"
        title = "Login page not loading"
        description = "Users are unable to access the login page. Getting 404 errors when trying to navigate to /login."
        sentiment = "NEGATIVE"
        priority = "HIGH"
    },
    @{
        ticket_id = "TICKET-002"
        timestamp = "2025-01-16T14:30:00"
        status = "OPEN"
        title = "Dashboard shows incorrect data"
        description = "Sales dashboard is displaying last month's data instead of current month. This is affecting our weekly reports."
        sentiment = "NEGATIVE"
        priority = "MEDIUM"
    },
    @{
        ticket_id = "TICKET-003"
        timestamp = "2025-01-17T09:15:00"
        status = "OPEN"
        title = "Email notifications not working"
        description = "Users are not receiving email notifications for ticket updates. Very frustrating experience!"
        sentiment = "NEGATIVE"
        priority = "HIGH"
    },
    @{
        ticket_id = "TICKET-004"
        timestamp = "2025-01-18T11:45:00"
        status = "OPEN"
        title = "Search function slow"
        description = "The search feature works but takes a long time to return results. Could be optimized."
        sentiment = "NEUTRAL"
        priority = "LOW"
    },
    @{
        ticket_id = "TICKET-005"
        timestamp = "2025-01-19T16:20:00"
        status = "OPEN"
        title = "Great new feature request"
        description = "Love the app! Would be amazing if we could add file attachments to tickets."
        sentiment = "POSITIVE"
        priority = "MEDIUM"
    },
    @{
        ticket_id = "TICKET-006"
        timestamp = "2025-01-20T08:00:00"
        status = "OPEN"
        title = "Mobile app crashes on startup"
        description = "The mobile version keeps crashing immediately after opening. Tried reinstalling but still broken."
        sentiment = "NEGATIVE"
        priority = "HIGH"
    },
    @{
        ticket_id = "TICKET-007"
        timestamp = "2025-01-20T12:30:00"
        status = "OPEN"
        title = "Thank you for quick support"
        description = "Just wanted to say thanks for the excellent customer service. My issue was resolved quickly."
        sentiment = "POSITIVE"
        priority = "LOW"
    },
    @{
        ticket_id = "TICKET-008"
        timestamp = "2025-01-21T15:45:00"
        status = "OPEN"
        title = "Export to CSV not working"
        description = "When I try to export my ticket list to CSV, nothing happens. No error message either."
        sentiment = "NEUTRAL"
        priority = "MEDIUM"
    }
)

Write-Host "Adding mock tickets to tickets_test table..." -ForegroundColor Cyan

foreach ($ticket in $mockTickets) {
    $item = @{
        ticket_id = @{S = $ticket.ticket_id}
        timestamp = @{S = $ticket.timestamp}
        status = @{S = $ticket.status}
        title = @{S = $ticket.title}
        description = @{S = $ticket.description}
        sentiment = @{S = $ticket.sentiment}
        priority = @{S = $ticket.priority}
    }

    $itemJson = $item | ConvertTo-Json -Compress -Depth 10

    Write-Host "Adding ticket: $($ticket.ticket_id)..." -ForegroundColor Yellow

    aws dynamodb put-item --table-name tickets_test --item $itemJson

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Successfully added $($ticket.ticket_id)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to add $($ticket.ticket_id)" -ForegroundColor Red
    }
}

Write-Host "`nDone! Verifying data..." -ForegroundColor Cyan
Write-Host "Total items in table:" -ForegroundColor Cyan
aws dynamodb scan --table-name tickets_test --select COUNT
Write-Host "`nAll tickets:" -ForegroundColor Cyan
aws dynamodb scan --table-name tickets_test --output table
