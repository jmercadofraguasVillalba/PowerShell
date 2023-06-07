# !!! Coded for all known types but tested only .rdl, .rds, .rsd, .kpi, .pbix for my needs !!!

# Set the variables
[string] $SQL_Reportserver   = "spadwhdev";    
[string] $PBIRS_DB           = "Carol";       
[string] $download_folder    = "c:\jmf\Informes20230601";  
   
# Extract data from report server database
$sql = "SELECT
	c.ItemID
	, c.Name
	, c.Path
	, c.Type
	, TypeDescription = 
		CASE c.Type
			WHEN 2 THEN 'SSRS Report'
			When 13 Then 'Power BI Report'

            -- Not tested ! Code works
            WHEN 1 THEN 'Folder'
            WHEN 3 THEN 'Resources'
            WHEN 4 THEN 'Linked Report'
            WHEN 5 THEN 'Data Source'
            WHEN 6 THEN 'Report Model'
            WHEN 7 THEN 'Report Part'
            WHEN 8 THEN 'Shared Dataset'
            -- 11 ... KPI
			ELSE 'Other Type (check/revisit)'

		END 
    , ISNULL(cc.ContentType,'SSRS') as ContentType
	, RDL_BinaryContent = IIF(c.Type <> 13, CONVERT(varbinary(max), c.[Content]), null)
	, PBIX_BinaryContent = IIF(c.Type = 13, CONVERT(varbinary(max), cc.[Content]), null)
    , cc.ContentType
FROM dbo.[Catalog] c
	LEFT JOIN dbo.[CatalogItemExtendedContent] cc ON c.ItemID = cc.ItemId AND cc.ContentType = 'CatalogItem'
WHERE c.TYPE IN (2, 5, 8, 11, 13)
 AND c.ItemID ='8C78C633-F57C-41D0-BF47-6FD0304FB1CB'
";        

cls

<#
    $SQL_Reportserver
    $PBIRS_DB
    $download_folder
    $sql
#>

Write-Output ((Get-Date -format yyyy-MM-dd-HH:mm:ss) + ": Started ...");
  
# DB connect using Integrated security
$conn = New-Object Data.SqlClient.SqlConnection;
$conn.ConnectionString = "Data Source=$SQL_Reportserver;Initial Catalog=$PBIRS_DB;Integrated Security=True;";
$conn.Open();
 
Write-Output ((Get-Date -format yyyy-MM-dd-HH:mm:ss) + ": Report Server DB - Connection success! ...");
 
$cmd = New-Object Data.SqlClient.SqlCommand $sql, $conn;
$rdr = $cmd.ExecuteReader();
# $invalids = [System.IO.Path]::GetInvalidFileNameChars();
 
# Loop
While ($rdr.Read())
{
    Try
    {
        Write-Output "------------------------------------------"
        $ItemName = $rdr.GetString(1);
        Write-Output "Reading $ItemName"
        
        #  foreach ($invalid in $invalids) 
        #      { $name = $name.Replace($invalid, "-"); }

        # $rdr.GetInt32(3)
        $ItemFileName = ""
        If ($rdr.GetInt32(3) -eq 2)        { $ItemFileName = $ItemName + ".rdl"; }
        ElseIf ($rdr.GetInt32(3) -eq 5)    { $ItemFileName = $ItemName + ".rds"; }
        ElseIf ($rdr.GetInt32(3) -eq 8 )    { $ItemFileName = $ItemName + ".rsd"; }
        ElseIf ($rdr.GetInt32(3) -eq 11)   { $ItemFileName = $ItemName + ".kpi"; }
        ElseIf ($rdr.GetInt32(3) -eq 13)   { $ItemFileName = $ItemName + ".pbix"; }

        if ($ItemFileName -ne "")
        {
            Write-Output ((Get-Date -format yyyy-MM-dd-HH:mm:ss) + ": Exporting {0} ... " -f $ItemFileName);
 
            $ItemName_Path = [System.IO.Path]::Combine($download_folder, $ItemFileName);
            #$ItemName_Path
            $fs = New-Object System.IO.FileStream ($ItemName_Path), Create, Write;
            $BinaryWriter = New-Object System.IO.BinaryWriter($fs);
 
            # Read Content 
            if ($rdr.GetString(4) -eq "Power BI Report") {
                $BinaryContent = $rdr.GetSqlBinary(7).Value;
            } 
            else
            {
                $BinaryContent = $rdr.GetSqlBinary(6).Value;
            }

            $BinaryWriter.Write($BinaryContent, 0, $BinaryContent.Length);
            $BinaryWriter.Flush();
            $BinaryWriter.Close();
            $fs.Close();
        }
        else 
        {
            Write-Output $ItemFileName "... !!! NOT exported"
            Write-Output $rdr.GetInt32(3)
            Write-Output $rdr.GetString(4)
        }       
    }
    Catch
    {
        Write-Output ($_.Exception.Message)
    }
    Finally
    {
        $fs.Dispose();
    }
}
 
# Cleanup
$rdr.Close();
$cmd.Dispose();
$conn.Close();
$conn.Dispose();

Write-Output "------------------------------------------" 
Write-Output ((Get-Date -format yyyy-MM-dd-HH:mm:ss) + ": Process Finished ... ")