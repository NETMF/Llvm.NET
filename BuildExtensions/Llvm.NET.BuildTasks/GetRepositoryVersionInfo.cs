using Microsoft.Build.Framework;
using Microsoft.Build.Utilities;

namespace Llvm.NET.BuildTasks
{
    public class GetRepositoryVersionInfo
        : Task
    {
        [Required]
        public string BuildVersionXmlFile { get; set; }

        [Required]
        public bool IsAutomatedBuild { get; set; }

        public bool IsPullRequestBuild { get; set; }

        [Output]
        public string SemVer { get; set; }

        [Output]
        public string NuGetVersion { get; set; }

        [Output]
        public ushort FileVersionMajor { get; set; }

        [Output]
        public ushort FileVersionMinor { get; set; }

        [Output]
        public ushort FileVersionBuild { get; set; }

        [Output]
        public ushort FileVersionRevision { get; set; }

        [Output]
        public string LlvmVersion { get; set; }

        public override bool Execute( )
        {
            var baseBuildVersionData = BuildVersionData.Load( BuildVersionXmlFile );
            CSemVer fullVersion = baseBuildVersionData.CreateSemVer( IsAutomatedBuild, IsPullRequestBuild );

            SemVer = fullVersion.ToString( true );
            NuGetVersion = fullVersion.ToString( false );
            FileVersionMajor = ( ushort )fullVersion.FileVersion.Major;
            FileVersionMinor = ( ushort )fullVersion.FileVersion.Minor;
            FileVersionBuild = ( ushort )fullVersion.FileVersion.Build;
            FileVersionRevision = ( ushort )fullVersion.FileVersion.Revision;

            LlvmVersion = baseBuildVersionData.LlvmVersion;
            return true;
        }
    }
}
