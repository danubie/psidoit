function Get-IdoItPSObjectMapped {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Alias('ObjectId','objID')]
        [int] $Id,
        [Parameter(Mandatory = $true)]
        [Hashtable] $PropertyMap
    )

    begin {

    }

    process {
        $obj = Get-IdoItObject -Id $Id
        if ($null -eq $obj) { return }

        $resultObj = @{
            ObjectId = $obj.Id
        }
        foreach ($propMap in $PropertyMap) {
            foreach ($thisMapping in $propMap.Mapping) {
                $catValues = Get-IdoItCategory -Id $obj.Id -Category $thisMapping.Category
                if ($null -eq $catValues) {
                    Write-Warning "No categories found for object type $($thisMapping.Category)($($obj.Objecttype))"
                    continue
                }
                # if no action is defined, add the property. If the corresponding catvalue holds an array, the property is added as an array
                foreach ($propListItem in ($thisMapping.PropertyList | Where-Object { [String]::IsNullOrEmpty($_.Action) })) {
                    if ($catValues.$($propListItem.iProperty) -is [System.Array]) {
                        $resultObj.Add($propListItem.PSProperty, @($catValues.$($propListItem.iProperty)))
                    } else {
                        $resultObj.Add($propListItem.PSProperty, $catValues.$($propListItem.iProperty))
                    }
                }
                foreach ($propListItem in ($thisMapping.PropertyList | Where-Object { $_.Action -is [scriptblock] })) {
                    # scriptblokc oarameter: if iProperty if it is defined else the whole object is passed to the action
                    if ([string]::IsNullOrEmpty($propListItem.iProperty)) {
                        $result = $propListItem.Action.InvokeReturnAsIs($propListItem.Action, $catValues)
                    } else {
                        $result = $propListItem.Action.InvokeReturnAsIs($propListItem.Action, $catValues.$($propListItem.iProperty))
                    }
                    $resultObj.Add($propListItem.PSProperty, $result)
                }
                # with action, the property is added as a single value depending on the action
                foreach ($propListItem in ($thisMapping.PropertyList | Where-Object { -not [String]::IsNullOrEmpty($_.Action) -and $_.Action -isnot [scriptblock] })) {
                    switch ($propListItem.Action) {
                        'Sum' {
                            $resultObj.Add($propListItem.PSProperty, ($catValues.$($propListItem.iProperty) |
                                Measure-Object -Sum | Select-Object -ExpandProperty Sum))
                            break
                        }
                        'Count' {
                            $resultObj.Add($propListItem.PSProperty, ($catValues | Measure-Object).Count)
                            break
                        }
                        Default {
                            $resultObj.Add($propListItem.PSProperty, $catValues.$($propListItem.iProperty))
                        }
                    }
                }
            }
        }
    }

    end {
        [PSCustomObject]$resultObj
    }
}
