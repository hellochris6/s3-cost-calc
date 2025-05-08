#!/bin/bash

# Author: Chris Blue
# Date: 2024-08-22
# Purpose: The script calculates the total cost to restore objects from S3 Glacier based on user input for object sizes, including detailed output. Information is logged to Airtable for Finance to review monthly.

# Function to calculate cost for a single object size
calculate_cost() {
  local size_in_gib="$1"
  
  # Convert size from GiB to GB
  local size_in_gb=$(echo "scale=2; $size_in_gib*1.07374" | bc -l)

  # Calculate costs
  local size_cost=$(echo "scale=2; $size_in_gib * 0.02" | bc -l)  # $0.02 per GiB
  local object_cost=$(echo "scale=2; $object_count / 1000 * 0.10" | bc -l)  # $0.10 per 1,000 objects

  # Total cost for this size
  local total_cost=$(echo "scale=2; $object_cost + $size_cost" | bc -l)

  # Return total cost, file size in GiB, and GB
  echo "$total_cost $size_in_gib $size_in_gb"
}

# Airtable API setup
WEBHOOK_URL="https://hooks.airtable.com/workflows/v1/genericWebhook/appSONbKopXoysRHO/wflKBgSRqQpZ1P3EB/wtrfk4KRvjtijukj8"

log_to_airtable() {
  local date="$1"
  local name="$2"
  local email="$3"
  local grand_total="$4"
  local total_gib="$5"
  local total_gb="$6"
  local total_objects="$7"
  local zendesk_ticket="$8"

  # Prepare the JSON payload for the webhook
  curl -X POST -H "Content-Type: application/json" -d '{
    "current_date": "'"$date"'",
    "requester_name": "'"$name"'",
    "requester_email": "'"$email"'",
    "grand_total": "'"$grand_total"'",
    "total_gib": "'"$total_gib"'",
    "total_gb": "'"$total_gb"'",
    "total_objects": "'"$total_objects"'",
    "zendesk_ticket": "'"$zendesk_ticket"'"
  }' "$WEBHOOK_URL"
}

# Main script starts here
# Prompt user for input
echo "AWS S3 Cost Calculator. 2024."
echo "To generate a cost estimate for restoring objects from S3 Glacier, enter the sizes of the objects in GiB (comma-separated if multiple):"
read -p "Object Sizes (GiB): " size_input

echo "What restore speed do you want for these files?
1 - Standard (12 hours)
2 - Bulk (48 hours)"
read restore_priority

echo "Do you want to keep files downloadable longer than the standard 1-day period?
1 - No
2 - Yes"
read restore_days

# Get number of days if yes
if [ "$restore_days" == "2" ]; then
  read -p "How many days do you want files to be downloadable? " restore_days
else
  restore_days=1  # Default to 1 day if "No" is selected
fi

# Set restore priority based on user input
if [[ "$restore_priority" == "1" ]]; then
  restore_priority="Standard"
elif [[ "$restore_priority" == "2" ]]; then
  restore_priority="Bulk"
else
  echo "Invalid restore speed selected. Exiting script." && exit 1
fi

# Convert input sizes to an array
IFS=',' read -r -a size_array <<< "$(echo "$size_input" | sed 's/, */,/g')"

# Initialize totals
grand_total=0
total_gib=0
total_gb=0
object_count=${#size_array[@]}  # Count total objects from input sizes

# Iterate through each size and calculate the cost
for size_in_gib in "${size_array[@]}"; do
  # Trim any leading/trailing spaces from the size input
  size_in_gib=$(echo "$size_in_gib" | xargs)
  
  echo "Processing size: $size_in_gib GiB..."
  
  # Calculate the cost, file size in GiB, and GB for this size
  result=$(calculate_cost "$size_in_gib")
  
  # Extract values from result
  cost=$(echo "$result" | cut -d' ' -f1)
  gib=$(echo "$result" | cut -d' ' -f2)
  gb=$(echo "$result" | cut -d' ' -f3)
  
  # Add to the grand totals
  grand_total=$(echo "$grand_total + $cost" | bc)
  total_gib=$(echo "$total_gib + $gib" | bc)
  total_gb=$(echo "$total_gb + $gb" | bc)
done

# Display the grand total and other details
echo "
Restore speed: $restore_priority
Keep files available for: $restore_days days
Total estimated cost: \$$grand_total (Estimated Total)
Total file size: $total_gib GiB ($total_gb GB)
Total number of objects: $object_count Objects
"

# Collect name and email of requester
echo "Please enter name of requester:"
read -r requester_name
echo "Please enter email of the requester:"
read -r requester_email
echo "Please enter corresponding Zendesk ticket:"
read -r zendesk_ticket

# Get the current date for logging
current_date=$(date +"%Y-%m-%d")

# Ask user if they need this information logged by entering Y or N
echo  "Would you like this information logged to Airtable? (Y/N):"
read user_choice

# If user enters Y, then proceed to send information to the webhook
if [[ "$user_choice" = "Y" || "$user_choice" == "y" ]]; then
  echo "Logging data to Airtable via webhook..."
  
  # Log data using the function
  log_to_airtable "$current_date" "$requester_name" "$requester_email" "$grand_total" "$total_gib" "$total_gb" "$object_count" "$zendesk_ticket"
  
  echo "Restore information has been logged to Airtable. Have a nice day!"
else 
  echo "Skipping logging process. The information will not be saved."
fi