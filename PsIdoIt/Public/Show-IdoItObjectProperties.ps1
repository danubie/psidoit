function Show-IdoItObjectProperties {
    <#
        .SYNOPSIS
        Shows all catagories for a given object id and the property values for each category.
        .DESCRIPTION
        Shows all catagories for a given object id and the property values for each category.
        The output is formatted as a table with the category name and the property values.
        This is only for debugging purposes and should not be used in production.
        .PARAMETER Id
        The id of the object you want to show the properties for.
        .PARAMETER WarnEmptyCategories
        If this switch is set, a warning will be shown if no categories are found for the object type.
        .EXAMPLE
        PS> Show-wwIdoitProperties -Id 540
        This will show all categories for the object with id 540 and the property values for each category.
        .EXAMPLE
        PS> Show-wwIdoitProperties -Id 540 -WarnEmptyCategories
        This will also show a warning if a category is empty (or not defined).
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("ObjectId")]
        [int] $Id,
        [switch] $WarnEmptyCategories
    )

    begin {

    }

    process {
        $obj = Get-IdoItObject -Id $Id
        if ($null -eq $obj) {
            Write-Warning "No object found with ID $Id"
            return
        }
        $catList = Get-IdoItObjectTypeCategory -Type $obj.Objecttype | Select-Object @{Name = 'ObjectId'; Expression = { $Id } }, *
        if ($null -eq $catList) {
            Write-Warning "No categories found for object type $($obj.Objecttype)"
            return
        }
        Write-Verbose "Found $($catList.Count) categories for object type $($obj.Objecttype)"
        foreach ($cat in $catList) {
            # if ($cat.type -eq 'custom') {
            #     Write-Warning "Custom category '$($cat.Title)' currently not supported"
            #     continue
            # }
            # Write-Warning "Category [$($cat.Title)] [$($cat.Const)]"
            $catValues = Get-IdoItCategory -Id $obj.Id -Category $cat.Const -ErrorAction SilentlyContinue
            if ($null -eq $catValues) {
                if ($WarnEmptyCategories) {
                    Write-Warning "No categories found for object type $($obj.Objecttype) and category $($cat.CONST)"
                }
                continue
            }
            Write-Host "Category: $($cat.Title)"
            $catValues | Format-Table -GroupBy RefCategory -AutoSize -Wrap
        }
    }

    end {

    }
}