BeforeDiscovery {
    $Script:moduleName = 'psIdoIt'
    $Script:projectRoot = ($PSScriptRoot -split 'psIdoIt' | Join-Path -ChildPath $Script:moduleName)[0]

    #region loading module
    $moduleRoot = Join-Path -Path $projectRoot -ChildPath $Script:moduleName
    if (-not (Get-Module -Name $Script:moduleName -ErrorAction SilentlyContinue)) {
        Import-Module $moduleRoot -Force -ErrorAction Stop
        Write-Warning "Module $Script:moduleName imported; Please login first (Connect-IdoIt)"
        Write-Warning "    You must set env:PSIDOIT_TESTS_INTEGRATION to a file path containing the test data in JSON format"
        return
    }
    #endregion
}
BeforeAll {
    $Script:moduleName = 'psIdoIt'
    $Script:projectRoot = ($PSScriptRoot -split 'psIdoIt' | Join-Path -ChildPath $Script:moduleName)[0]
}
AfterAll {
}

Describe 'Get-IdoItPSObjectMapped' {
    BeforeAll {
        Mock 'Connect-IdoIt' -ModuleName 'psIdoIt' -MockWith {
            Write-Host "Connect-IdoIt called with $($args | Out-String)"
            return $true
        }
        $mapUser = @{
            PSType  = 'MyUser'
            Mapping = @(
                @{
                    Category     = 'C__CATS__PERSON';
                    PropertyList = @(
                        @{ PSProperty = 'Id'; IProperty = 'Id' },
                        @{ PSProperty = 'Name'; IProperty = 'Title' }
                    )
                }
            )
        }
        $mapServer = @{
            PSType  = 'MyServer'
            Mapping = @(
                @{
                    Category     = 'C__CATG__GLOBAL'
                    PropertyList = @(
                        @{ PSProperty = 'Id'; IProperty = 'Id' }
                        @{ PSProperty = 'Kommentar'; IProperty = 'Description' }
                        @{ PSProperty = 'CDate'; IProperty = 'Created' }
                        @{ PSProperty = 'EDate'; IProperty = 'Changed' }
                    )
                }
                @{
                    Category     = 'C__CATG__MEMORY'
                    PropertyList = @(
                        @{ PSProperty = 'MemoryGB'; IProperty = 'Capacity'; Action = 'Sum' }
                        @{ PSProperty = 'MemoryMB'; IProperty = 'Capacity'; Action = {
                            $args[1] | Foreach-Object { $_*1024 } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
                        } }
                        @{ PSProperty = 'MemoryMBFromUnits'; IProperty = ''; Action = {
                            $tempresult = $args[1] | Foreach-Object {
                                $idoitProperty = $_
                                switch ($_.Unit) {
                                    'MB' { $idoitProperty.Capacity; break }
                                    'GB' { 1024*$idoitProperty.Capacity; break }
                                    'TB' { 1024*1024*$idoitProperty.Capacity; break }
                                    Default { Write-Error "Unknown unit $_" }
                                }
                            }
                            $tempresult | Measure-Object -Sum | Select-Object -ExpandProperty Sum
                        } }
                        @{ PSProperty = 'NbElements'; IProperty = 'Capacity'; Action = 'Count' }
                        @{ PSProperty = 'AsArray'; Action = { $args[1] } }
                    )
                }
            )
        } #$contentJson.result | % { $_ | Select -ExpandProperty catg; $_ | Select -ExpandProperty cats   }
        $TDIdoitPerson = @(
            @{ id = 37; title = 'Wolfgang Wagner'; objecttype = 53; type_title = 'Persons' }
        )
        $TDIdoitCategory = @(
            @{ RefCategory = 'C__CATS__PERSON';    Id = 540;  Title = 'Wolfgang Wagner'; Objecttype = 53; TypeTitle = 'Persons' }
            @{ RefCategory = 'C__OBJTYPE__SERVER'; Id = 540; Title = 'server540';       Objecttype =  5; TypeTitle = 'Server' }
            @{ RefCategory = 'C__CATG__MEMORY';    Id = 540; Title = 'CPU1';            Objecttype =  4; TypeTitle = 'CPU';    Cores = 1 }
            @{ RefCategory = 'C__CATG__CONTACT';   Id = 540; Contact = 'Donald Duck'; ContactId = $null; Primary = 'No'; }
            @{ RefCategory = 'C__CATG__GLOBAL'; Id = 540; Title = 'server540'; Type = 'Server'; Description = 'this is it' }
            @{ RefCategory = 'C__CATG__MEMORY'; Id = 540; Title = 'DDRAM'; TotalCapacity = 68719476736; Capacity = 64; Unit = 'GB'; }
            @{ RefCategory = 'C__CATG__MEMORY'; Id = 540; Title = 'DDRAM'; TotalCapacity = 68719476736; Capacity = 64; Unit = 'GB'; }
        )
        Mock -CommandName Connect-Idoit -ModuleName 'psIdoIt' -MockWith {}
        Mock -CommandName Get-IdoItVersion -ModuleName 'psIdoIt' -MockWith {}

        #region Mock for Get-IdoItObject (cmdb.object.read)
        Mock -CommandName Invoke-Idoit -ModuleName 'psIdoIt' -MockWith {
            $hash = switch ($Params.Id) {
                37  { @{ id = 37;  objID = 37; title = 'Wolfgang Wagner'; Objecttype = 53; } }
                540 { @{ id = 540; objId = 540; title = 'pesterServer540'; ObjectType = 5; } }
            }
            $hash | Foreach-Object { [PSCustomObject] $_ }
        } -ParameterFilter { $Method -eq 'cmdb.object.read' }
        #endregion

        #region Mock for Get-IdoItObjectTypeCategory (cmdb.object_type_categories.read)
        # How to gather testdata? with breackpoint at the end of the function
        # $contentJson.result.catg | ? const -in 'C__CATG__GLOBAL','C__CATG__MEMORY' | ConvertFrom-ObjectToString -OutputType PSCustomObject
        # $contentJson.result.cats | ? const -in 'C__CATS__SOMETHING1','C__CATS__SOMETHING2' | ConvertFrom-ObjectToString -OutputType PSCustomObject
        Mock -CommandName Invoke-Idoit -ModuleName 'psIdoIt' -MockWith {
            $hash = switch ($params.type) {
                53  {
                    @{
                        catg = @(
                            [PSCustomObject]@{ Id=31; title='Overview'; const='C__CATG__OVERVIEW'; multi_value='0'; source_table='isys_catg_overview' }
                            [PSCustomObject]@{ Id=1; title='General'; const='C__CATG__GLOBAL'; multi_value='0'; source_table='isys_catg_global' }
                        )
                        cats = @(
                            [PSCustomObject]@{ Id=48; title='Persons'; const='C__CATS__PERSON'; multi_value='0'; source_table='isys_cats_person_list' }
                        )
                    }
                }
                5   {
                    @{
                        catg = @(
                            [PSCustomObject] @{ id = 1; title = 'General'; const = 'C__CATG__GLOBAL'; multi_value = 0; source_table = 'isys_catg_global'; }
                            [PSCustomObject] @{ id = 5; title = 'Memory'; const = 'C__CATG__MEMORY'; multi_value = 1; source_table = 'isys_catg_memory'; }
                        )
                    }
                }
            }
            [PSCustomObject] $hash
        } -ParameterFilter { $Method -eq 'cmdb.object_type_categories.read' }
        #endregion

        #region Mock for Get-IdoItCategory (cmdb.category.read)
        Mock -CommandName Invoke-Idoit -ModuleName 'psIdoIt' -MockWith {
            switch ("$($params.objId)|$($params.Category)") {
                '37|C__CATS__PERSON' {
                    $result = [PSCustomObject] @{ id = 37; objID = 37; title = 'Wolfgang Wagner'; first_name = 'Wolfgang'; last_name = 'Wagner' }
                }
                '540|C__CATG__GLOBAL' {
                    $result = [PSCustomObject] @{ id = 540; objID = 540; title = 'server540'; type_title = 'Server'; description = 'this is it' }
                }
                '540|C__CATG__MEMORY' {
                    $result = @(
                        [PSCustomObject] @{ id = 540; objID = 540; title = 'DDRAM'; total_capacity = 68719476736; capacity = 64; unit = 'GB' }
                        [PSCustomObject] @{ id = 540; objID = 540; title = 'DDRAM'; total_capacity = 68719476736; capacity = 64; unit = 'GB' }
                        [PSCustomObject] @{ id = 540; objID = 540; title = 'DDRAM'; total_capacity = 68719476736; capacity = 64; unit = 'GB' }
                        [PSCustomObject] @{ id = 540; objID = 540; title = 'DDRAM'; total_capacity = 68719476736; capacity = 64; unit = 'GB' }
                    )
                }
            }
            $result
        } -ParameterFilter { $Method -eq 'cmdb.category.read' }
        #endregion

        #region Catch calls, which we did not expect
        Mock -CommandName Invoke-Idoit -ModuleName 'psIdoIt' -MockWith { Throw "Method $Method not mocked or filter isn't perfect $([PSCustomObject]$params)" }
        #endregion
    }
    It 'Should get object mapped to MyUser' {
        $objId = $TDIdoitPerson.Id

        $result = Get-IdoItPSObjectMapped -Id $ObjId -PropertyMap $mapUser
        $result | Should -Not -BeNullOrEmpty
        $result.Id | Should -Be $objId
        $result.Name | Should -Be 'Wolfgang Wagner'
    }
    It 'Should get object mapped to MyServer' {
        $objId = 540
        $result = Get-IdoItPSObjectMapped -Id $objId -PropertyMap $mapServer
        $result | Should -Not -BeNullOrEmpty
        $result.Id | Should -Be $objId
        $result.MemoryGB | Should -Be (4*64)
        $result.MemoryMB | Should -Be (4*64*1024)
        $result.MemoryMBFromUnits | Should -Be (4*64*1024)
        $result.NbElements | Should -Be 4
        $result.AsArray | Should -HaveCount 4
    }
}