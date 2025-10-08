package mount

import (
	"fmt"
	"os/exec"
	"strings"

	"kopia-manager/internal/manager"
	"kopia-manager/internal/ui"

	"github.com/charmbracelet/log"
	"github.com/spf13/cobra"
)

// MountCmd mounts a snapshot as a filesystem using FUSE.
var MountCmd = &cobra.Command{
	Use:   "mount [snapshot-id] [mount-point]",
	Short: "Mount a snapshot as a filesystem using FUSE",
	Long: `Mount a snapshot as a filesystem using FUSE.

The snapshot-id can be:
- A specific snapshot ID (e.g., 'k1a2b3c4d5e6f7g8h9i0')
- 'all' to mount all snapshots in a unified view

Examples:
  kopia-manager mount k1a2b3c4d5e6f7g8h9i0 /mnt/backup
  kopia-manager mount all /mnt/all-backups`,
	Args: cobra.ExactArgs(2),
	Run: func(cmd *cobra.Command, args []string) {
		km := manager.NewKopiaManager()
		snapshotID := args[0]
		mountPoint := args[1]
		browse, _ := cmd.Flags().GetBool("browse")

		log.Info("Mounting snapshot", "snapshot", snapshotID, "mountPoint", mountPoint)

		if err := km.MountSnapshot(snapshotID, mountPoint); err != nil {
			log.Fatal("Mount failed", "error", err)
		}

		if browse {
			if err := openFileManager(mountPoint); err != nil {
				log.Warn("Failed to open file manager", "error", err)
			}
		}
	},
}

// UnmountCmd unmounts a previously mounted snapshot.
var UnmountCmd = &cobra.Command{
	Use:   "unmount [mount-point]",
	Short: "Unmount a previously mounted snapshot",
	Long: `Unmount a previously mounted snapshot filesystem.

Examples:
  kopia-manager unmount /mnt/backup
  kopia-manager unmount /mnt/all-backups`,
	Args: cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		km := manager.NewKopiaManager()
		mountPoint := args[0]

		log.Info("Unmounting", "mountPoint", mountPoint)

		if err := km.UnmountSnapshot(mountPoint); err != nil {
			log.Fatal("Unmount failed", "error", err)
		}
	},
}

// ListMountsCmd lists active kopia FUSE mounts.
var ListMountsCmd = &cobra.Command{
	Use:   "list-mounts",
	Short: "List active kopia FUSE mounts",
	Run: func(cmd *cobra.Command, args []string) {
		mounts, err := listActiveMounts()
		if err != nil {
			log.Fatal("Failed to list mounts", "error", err)
		}

		if len(mounts) == 0 {
			fmt.Println("No active kopia mounts found.")
			return
		}

		table := ui.NewTableBuilder(" Active Kopia Mounts ")
		table.AddColumn("Mount Point", ui.Dynamic)
		table.AddColumn("Source", ui.Dynamic)
		table.AddColumn("Type", ui.Dynamic)

		for _, mount := range mounts {
			table.AddRow(mount.MountPoint, mount.Source, mount.Type)
		}

		fmt.Print(table.Build())
	},
}

func init() {
	// Local flag wiring for mount command; guard to avoid double-registration.
	if MountCmd.Flags().Lookup("browse") == nil {
		MountCmd.Flags().BoolP("browse", "b", false, "Open file manager after mounting")
	}
}

// openFileManager attempts to open the file manager at the given path.
func openFileManager(path string) error {
	var cmd *exec.Cmd

	// Try different file managers based on availability
	if _, err := exec.LookPath("xdg-open"); err == nil {
		cmd = exec.Command("xdg-open", path)
	} else if _, err := exec.LookPath("nautilus"); err == nil {
		cmd = exec.Command("nautilus", path)
	} else if _, err := exec.LookPath("dolphin"); err == nil {
		cmd = exec.Command("dolphin", path)
	} else if _, err := exec.LookPath("thunar"); err == nil {
		cmd = exec.Command("thunar", path)
	} else {
		return fmt.Errorf("no supported file manager found")
	}

	return cmd.Start()
}

// MountInfo represents information about an active mount.
type MountInfo struct {
	MountPoint string
	Source     string
	Type       string
}

// listActiveMounts returns a list of active kopia-related mounts.
func listActiveMounts() ([]MountInfo, error) {
	cmd := exec.Command("mount")
	output, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to run mount command: %w", err)
	}

	var mounts []MountInfo
	lines := strings.Split(string(output), "\n")

	for _, line := range lines {
		// Look for FUSE mounts that might be kopia-related
		if strings.Contains(line, "fuse") && (strings.Contains(line, "kopia") || strings.Contains(line, "type fuse")) {
			fields := strings.Fields(line)
			if len(fields) >= 3 {
				// Parse mount line: source on mountpoint type options
				for i, field := range fields {
					if field == "on" && i+1 < len(fields) {
						mountPoint := fields[i+1]
						source := fields[0]
						mountType := "fuse"

						if i+3 < len(fields) && fields[i+2] == "type" {
							mountType = fields[i+3]
						}

						mounts = append(mounts, MountInfo{
							MountPoint: mountPoint,
							Source:     source,
							Type:       mountType,
						})
						break
					}
				}
			}
		}
	}

	return mounts, nil
}
