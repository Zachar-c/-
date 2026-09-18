$args | ForEach-Object { Write-Output [string]$_ }
if ('1' -eq 0) {
    Write-Output 'Tests           0)'
    Write-Output 'Passing Tests   0)'
} else {
    Write-Output 'Tests           0'
    Write-Output 'Passing Tests   0'
    Write-Output 'Failing Tests  1'
}
exit 1
