# GitHub Project Configuration: Anime Dub Studio — Product & Engineering Roadmap

**Board Name:** Anime Dub Studio — Product & Engineering Roadmap  
**Target Repository:** `dikshant363/anime-dub-studio`  
**Board Type:** GitHub Projects (Projects v2)

---

## 1. Workflow Columns (Status Field)

The project board tracks items across seven sequential workflow stages:

1. **Backlog:** Unscheduled feature requests, research ideas, and future backlog candidates.
2. **Ready:** Prioritized, specced issues with clear acceptance criteria ready for implementation.
3. **In Progress:** Work actively being implemented in a working branch.
4. **Blocked:** Tasks waiting on external prerequisites (e.g. Apple Developer Program signing credentials).
5. **In Review:** Pull requests undergoing code review, static analysis, and automated CI.
6. **Testing:** Implemented features undergoing integration testing and real-media audio/video auditioning.
7. **Done:** Merged, tested, and released capabilities.

---

## 2. Configured Custom Fields

| Field Name | Type | Options / Values | Purpose |
| :--- | :--- | :--- | :--- |
| **Status** | Single Select | Backlog, Ready, In Progress, Blocked, In Review, Testing, Done | Workflow progression |
| **Priority** | Single Select | `P0 Critical`, `P1 High`, `P2 Medium`, `P3 Low` | Urgency triage |
| **Milestone / Release** | Iteration / Select | `v2.1.1`, `v2.2.0`, `v2.3.0`, `v2.4.0`, `v2.5.0`, `v3.0.0` | Target delivery gate |
| **Work Type** | Single Select | `Feature`, `Bug`, `Security`, `Quality`, `Performance`, `Documentation`, `Research`, `Maintenance` | Categorization |
| **Area** | Single Select | `SwiftUI`, `Speech`, `Translation`, `Media Pipeline`, `Audio`, `Export`, `Storage`, `CI/CD`, `Documentation` | Architectural domain |
| **Effort** | Single Select | `Small` (1-2 days), `Medium` (3-5 days), `Large` (1-2 weeks) | Sizing |

---

## 3. Configured Project Views

1. **Roadmap View:**
   - Layout: Roadmap / Gantt
   - Group by: `Milestone / Release`
   - Shows chronological target milestones from v2.1.1 through v3.0.0.
2. **Board View:**
   - Layout: Board (Kanban)
   - Columns: `Status` (Backlog → Done)
   - Displays all active cards with Priority and Area badges.
3. **Bugs & Reliability View:**
   - Layout: Table
   - Filter: `Work Type:Bug` or `Priority:P0 Critical`
   - Sorted by: Priority ascending.
4. **Security & Quality View:**
   - Layout: Table
   - Filter: `Work Type:Security,Quality`
   - Tracks audit findings, CodeQL alerts, and test coverage improvements.
5. **Next Release View:**
   - Layout: Board
   - Filter: `Milestone:v2.2.0`
   - Displays only work items targeted for the immediate upcoming release.
6. **Completed Work View:**
   - Layout: Table
   - Filter: `Status:Done`
   - Sorted by: Updated date descending for release changelog compilation.

---

## 4. Setup Instructions via GitHub Web UI

Because the current CLI authentication token lacks the OAuth `read:project`/`project` scope, follow these one-time steps to publish the project board:

1. Navigate to: `https://github.com/users/dikshant363/projects/new`
2. Select **Board** template and name the project:
   `Anime Dub Studio — Product & Engineering Roadmap`
3. Link the repository `dikshant363/anime-dub-studio`.
4. Add the Custom Fields and Views defined in Sections 2 and 3 above.
5. Add issues `#1` through `#10` to their respective columns.
