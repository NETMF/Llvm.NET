using System;
using System.IO;
using LibGit2Sharp;

namespace Llvm.NET.BuildTasks
{
    internal enum BuildMode
    {
        LocalDev,
        PullRequest,
        ContinuousIntegration,

        // official release published publicly, may be a pre-release version but not a CI build
        OfficialRelease
    }

    public class BuildVersionData
    {
        public UInt16 BuildMajor { get; private set; }

        public UInt16 BuildMinor { get; private set; }

        public UInt16 BuildPatch { get; private set; }

        public string PreReleaseName { get; private set; }

        public byte PreReleaseNumber { get; private set; }

        public byte PreReleaseFix { get; private set; }

        public UInt16 LlvmVersionMajor { get; private set; }

        public UInt16 LlvmVersionMinor { get; private set; }

        public UInt16 LlvmVersionPatch { get; private set; }

        public string ReleaseBranch { get; private set; }

        public string LlvmVersion => $"{LlvmVersionMajor}.{LlvmVersionMinor}.{LlvmVersionPatch}";

        public string BuildVersionXmlFile { get; private set; }

        public CSemVer CreateSemVer( bool isAutomatedBuild, bool isPullRequestBuild )
        {
            using( var repo = new LibGit2Sharp.Repository( Path.GetDirectoryName( BuildVersionXmlFile ) ) )
            {
                Commit head = repo.Head.Tip;

                IPrereleaseVersion preReleaseInfo = null;
                var buildMode = repo.GetBuildMode( isAutomatedBuild, isPullRequestBuild, ReleaseBranch );
                switch( buildMode )
                {
                case BuildMode.LocalDev:
                    // local dev builds are always newer than any other builds
                    preReleaseInfo = new CIPreReleaseVersion( "DEV", GetBuildIndexFromUtc( DateTime.Now ), "zz" );
                    break;

                case BuildMode.PullRequest:
                    // PR builds should have a higher precedence than CI or release so that the
                    // builds pull in the components built in previous stages of the current build
                    // instead of the official CI or released builds.
                    preReleaseInfo = new CIPreReleaseVersion( "PRQ", GetBuildIndexFromUtc( head.Author.When.UtcDateTime ), "pr" );
                    break;

                case BuildMode.ContinuousIntegration:
                    preReleaseInfo = new CIPreReleaseVersion( "BLD", GetBuildIndexFromUtc( DateTime.Now ) );
                    break;

                case BuildMode.OfficialRelease:
                    if( !string.IsNullOrWhiteSpace( PreReleaseName ) )
                    {
                        preReleaseInfo = new OfficialPreRelease( PreReleaseName, PreReleaseNumber, PreReleaseFix );
                    }

                    break;

                default:
                    throw new InvalidOperationException( "Unexpected/Unsupported repository state" );
                }

                return new CSemVer( BuildMajor, BuildMinor, BuildPatch, preReleaseInfo, head.Id.Sha.Substring( 0, 8 ) );
            }
        }

        public static BuildVersionData Load( string path )
        {
            var retVal = new BuildVersionData( );
            using( var stream = File.OpenText( path ) )
            {
                var xdoc = System.Xml.Linq.XDocument.Load( stream, System.Xml.Linq.LoadOptions.None );
                var data = xdoc.Element( "BuildVersionData" );

                retVal.BuildVersionXmlFile = path;
                retVal.BuildMajor = Convert.ToUInt16( data.Attribute( "BuildMajor" ).Value );
                retVal.BuildMinor = Convert.ToUInt16( data.Attribute( "BuildMinor" ).Value );
                retVal.BuildPatch = Convert.ToUInt16( data.Attribute( "BuildPatch" ).Value );

                retVal.LlvmVersionMajor = Convert.ToUInt16( data.Attribute( "LlvmVersionMajor" ).Value );
                retVal.LlvmVersionMinor = Convert.ToUInt16( data.Attribute( "LlvmVersionMinor" ).Value );
                retVal.LlvmVersionPatch = Convert.ToUInt16( data.Attribute( "LlvmVersionPatch" ).Value );

                retVal.ReleaseBranch = data.Attribute( "ReleaseBranch" ).Value;

                var preRelName = data.Attribute( "PreReleaseName" );
                if( preRelName != null )
                {
                    retVal.PreReleaseName = preRelName.Value;
                    var preRelNumber = data.Attribute( "PreReleaseNumber" );
                    if( preRelNumber != null )
                    {
                        retVal.PreReleaseNumber = Convert.ToByte( preRelNumber.Value );
                        var preRelFix = data.Attribute( "PreReleaseFix" );
                        if( preRelFix != null )
                        {
                            retVal.PreReleaseFix = Convert.ToByte( preRelFix.Value );
                        }
                    }
                }
            }

            return retVal;
        }

        // For details on the general algorithm used for computing the numbers here see:
        // https://msdn.microsoft.com/en-us/library/system.reflection.assemblyversionattribute.assemblyversionattribute(v=vs.140).aspx
        // Only difference is this uses UTC as the basis to ensure the numbers consistently increase.
        private static string GetBuildIndexFromUtc( DateTime now )
        {
            var midnightTodayUtc = new DateTime( now.Year, now.Month, now.Day, 0, 0, 0, DateTimeKind.Utc );
            var baseDate = new DateTime( 2000, 1, 1, 0, 0, 0, DateTimeKind.Utc );
            uint buildNumber = ( ( uint )( now - baseDate ).Days ) << 16;
            buildNumber += ( ushort )( ( now - midnightTodayUtc ).TotalSeconds / 2 );
            return buildNumber.ToString( "X08" );
        }
    }
}
