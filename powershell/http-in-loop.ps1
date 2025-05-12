# ### CONFIGURATION !!! 
$endpoint = "http://localhost:64859/nejaky-endpoint"
$count = 1414    # number of records to be processed (taken from DB for example)
$take = 50       # endpoint limit (?take parametr for example)
$sleep = 30      # 30 seconds sleeping
# ### END OF CONFIGURATION
     
     
$total_steps_needed = [Math]::ceiling( ($count/$take))   # number of steps necessary to finish all the records
write-host "total number of steps: " $total_steps_needed   # debuging
     
for($i=0; $i -le $total_steps_needed; $i++) {
    $start_date = (GET-DATE)
    $response = Invoke-WebRequest -Uri $endpoint -Method Get -UseBasicParsing
    $end_date = (GET-DATE)
    $diff = NEW-TIMESPAN –Start $start_date –End $end_date  # doba trvani
     
    write-host "step " $i " executed in " $diff " with output: " $response
    Start-Sleep $sleep
    write-host "`n"
}
     
write-host "end"
