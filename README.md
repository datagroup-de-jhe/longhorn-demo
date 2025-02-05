
<![endif]-->

**Ziel des Demos**

Dieses Demo demonstriert die Hochverfügbarkeit und Widerstandsfähigkeit von Longhorn bei verschiedenen Ausfällen in einem Kubernetes-Cluster. Es zeigt, dass Longhorn auch bei schwerwiegenderen Störungen weiterhin stabil und performant ist.

**Was wird gezeigt?**

**Setup:**

-   Installation von Longhorn.
-   Erstellung eines RWX-Volumes mit 3 Replicas.
-   Bereitstellung einer Testanwendung, die auf das RWX-Volume zugreift.

**Tests:**

-   Simulation von Ausfällen:

-   Manager-Ausfall.
-   Engine-Ausfall.
-   Replica-Ausfall.
-   Node-Ausfall.

-   Demonstration der Recovery-Mechanismen von Longhorn.
-   Überwachung der Verfügbarkeit der Testanwendung während der Tests.

**Latenzüberwachung:**

-   Kontinuierliches Monitoring der Antwortzeit der Testanwendung, um zu zeigen, dass sie weiterhin erreichbar ist.

**Workload-Test:**

-   Führt realistische I/O-Workloads mit `kbench` aus, um die Performance von Longhorn unter Last zu demonstrieren.

**Automatisiertes Cleanup:**

-   Nach jedem Test wird der Cluster automatisch bereinigt, um einen sauberen Zustand für den nächsten Test zu gewährleisten.

**Erwartetes Ergebnis**

-   Die Testanwendung bleibt während der gesamten Tests lesend/schreibend verfügbar.
-   Longhorn führt automatische Failover- und Rekonstruktion-Prozesse durch.
-   Die Latenz bleibt konstant, selbst bei Ausfällen.


## Übersicht der Variablen

-   **NAMESPACE**: Namespace, in dem Longhorn installiert und betrieben wird (Standard: `longhorn-system`).
-   **VOLUME_NAME**: Name des Longhorn Volumes, das erstellt werden soll (Standard: `rwx-volume`).
-   **PVC_NAME**: Name des PersistentVolumeClaim, der das Volume referenziert (Standard: `rwx-pvc`).
-   **DEPLOYMENT_NAME**: Name des Testdeployments (Standard: `rwx-test`).
-   **APP_PORT**: Lokaler Port, über den die Testanwendung (NGINX) erreichbar gemacht wird (Standard: `8081`).
-   **DASHBOARD_PORT**: Lokaler Port, über den das Longhorn-Dashboard erreichbar gemacht wird (Standard: `8080`).
-   **KBENCH_DEPLOYMENT_NAME**: Name eines weiteren Deployments (hier als `kbench-test` definiert, wird in diesem Skript aber nicht weiter verwendet).

----------

## Targets im Detail

### `help`

-   **Beschreibung**: Zeigt eine Hilfe an, in der alle verfügbaren Makefile-Targets sowie deren Beschreibung ausgegeben werden.
-   **Funktionsweise**: Liest die Kommentare in den Makefile-Zielen aus und formatiert sie farbig in der Konsole.

----------

### `install-longhorn`

-   **Beschreibung**: Installiert Longhorn im Kubernetes-Cluster.
-   **Ablauf**:
    1.  Fügt das Longhorn-Helm-Repository hinzu (falls nicht bereits vorhanden).
    2.  Aktualisiert das Helm-Repository.
    3.  Erstellt den Namespace, in dem Longhorn betrieben wird.
    4.  Installiert Longhorn über Helm im angegebenen Namespace.

----------

### `create-volume`

-   **Beschreibung**: Erstellt ein Longhorn Volume mit ReadWriteMany (RWX)-Zugriff.
-   **Ablauf**:
    1.  Wartet darauf, dass die Longhorn Manager-Pods im gewünschten Namespace den Status `Running` erreicht haben.
    2.  Wendet eine YAML-Definition an, die ein Volume mit 1Gi Größe, 3 Repliken und RWX-Zugriff konfiguriert.

----------

### `create-pvc`

-   **Beschreibung**: Erstellt einen PersistentVolumeClaim (PVC) für das RWX-Volume.
-   **Ablauf**:
    1.  Wendet eine YAML-Definition an, die einen PVC mit einer Anforderung von 1Gi Speicher, RWX-Zugriff und Verweis auf das zuvor erstellte Volume definiert.

----------

### `create-deployment`

-   **Beschreibung**: Erstellt ein Testdeployment basierend auf dem NGINX-Container.
-   **Ablauf**:
    1.  Erzeugt ein Deployment mit einem Replikat.
    2.  Der NGINX-Container wird gestartet und mountet den PVC unter dem Pfad `/usr/share/nginx/html`.
    3.  Damit wird die Nutzung des Longhorn-Volumes innerhalb des Deployments demonstriert.

----------

### `create-service`

-   **Beschreibung**: Erstellt einen ClusterIP-Service zur internen Erreichbarkeit des Testdeployments.
-   **Ablauf**:
    1.  Erzeugt einen Service, der den NGINX-Container (auf Port 80) über den ClusterIP-Typ verfügbar macht.

----------

### `expose-dashboard`

-   **Beschreibung**: Stellt das Longhorn-Dashboard über Port-Forwarding bereit.
-   **Ablauf**:
    1.  Führt einen Port-Forwarding-Befehl aus, der den Longhorn Dashboard-Service (vermutlich `longhorn-frontend`) auf den lokalen Port `$(DASHBOARD_PORT)` weiterleitet.

----------

### `expose-app`

-   **Beschreibung**: Stellt die Testanwendung (NGINX) über Port-Forwarding bereit.
-   **Ablauf**:
    1.  Ermittelt den Namen eines Pods, der zum Testdeployment gehört.
    2.  Führt einen Port-Forwarding-Befehl aus, der den Pod-Port 80 auf den lokalen Port `$(APP_PORT)` weiterleitet.

----------

### `stop-port-forwarding`

-   **Beschreibung**: Beendet alle aktiven Port-Forwarding-Prozesse.
-   **Ablauf**:
    1.  Nutzt den `pkill`-Befehl, um alle Prozesse zu beenden, die `kubectl port-forward` ausführen.

----------

### `check-status`

-   **Beschreibung**: Überprüft den Status der Longhorn-Komponenten und des Testdeployments.
-   **Ablauf**:
    1.  Listet alle Longhorn-Pods im entsprechenden Namespace auf.
    2.  Zeigt Informationen zum PVC und dem zugehörigen PersistentVolume an.
    3.  Überprüft, ob das Testdeployment und der zugehörige Service laufen.

----------

### `check-app-availability`

-   **Beschreibung**: Prüft, ob die Testanwendung (NGINX) über den lokal weitergeleiteten Port erreichbar ist.
-   **Ablauf**:
    1.  Führt wiederholte `curl`-Abfragen an `http://localhost:$(APP_PORT)` durch.
    2.  Wartet so lange, bis eine HTTP-200-Antwort zurückkommt.
    3.  Gibt eine Erfolgsmeldung aus, wenn die Anwendung erreichbar ist.

> **Hinweis**: Es existieren in diesem Makefile zwei Definitionen für `check-app-availability`. Dies könnte ein Versehen sein. Die jeweils erste oder letzte Definition wird genutzt.

----------

### `full-setup`

-   **Beschreibung**: Führt den kompletten Setup-Prozess durch.
-   **Ablauf**:
    1.  Installiert Longhorn.
    2.  Erstellt das Volume und den PVC.
    3.  Setzt das Testdeployment und den zugehörigen Service auf.
    4.  Stellt das Dashboard und die Testanwendung via Port-Forwarding bereit.
    5.  Überprüft den Status und die Erreichbarkeit der Testanwendung.
    6.  Gibt abschließend eine Erfolgsmeldung aus.

----------

### Simulation von Ausfällen

#### `simulate-manager-failure`

-   **Beschreibung**: Simuliert den Ausfall eines Longhorn Manager-Pods.
-   **Ablauf**:
    1.  Ermittelt den Namen eines Longhorn Manager-Pods.
    2.  Löscht den Pod, um einen Ausfall zu simulieren.
    3.  Wartet kurz, damit ein neuer Manager-Pod starten kann.

#### `simulate-engine-failure`

-   **Beschreibung**: Simuliert den Ausfall eines Longhorn Engine-Pods.
-   **Ablauf**:
    1.  Ermittelt den Namen eines Engine-Pods.
    2.  Löscht diesen Pod.
    3.  Wartet, bis ein neuer Engine-Pod startet.

#### `simulate-replica-failure`

-   **Beschreibung**: Simuliert den Ausfall eines Longhorn Replica-Pods.
-   **Ablauf**:
    1.  Ermittelt den Namen eines Replica-Pods.
    2.  Löscht diesen Pod.
    3.  Wartet, bis eine neue Replica gestartet wird.

----------

### Node-Verwaltung (Simulation von Node-Ausfällen)

#### `drain-node`

-   **Beschreibung**: Simuliert einen Node-Ausfall, indem ein Node "gedrained" wird.
-   **Ablauf**:
    1.  Ermittelt einen aktiven (Ready) Node.
    2.  Führt den `kubectl drain` Befehl aus, um den Node für geplante Wartungsarbeiten oder zum Ausfall zu simulieren.

#### `uncordon-node`

-   **Beschreibung**: Setzt einen zuvor gedraineden Node wieder in den normalen Betrieb.
-   **Ablauf**:
    1.  Ermittelt einen Node, der sich im Zustand `SchedulingDisabled` befindet.
    2.  Führt `kubectl uncordon` aus, um den Node wieder freizugeben.

----------

### Monitoring und Beobachtung

#### `watch-replicas`

-   **Beschreibung**: Überwacht kontinuierlich den Status der Longhorn Replicas.
-   **Ablauf**: Nutzt den Befehl `watch`, um regelmäßig den Output von `kubectl -n $(NAMESPACE) get replica` anzuzeigen.

#### `watch-pods`

-   **Beschreibung**: Zeigt kontinuierlich den Status aller Pods im Cluster (mit zusätzlichen Informationen wie Node und IP) an.
-   **Ablauf**: Nutzt `watch kubectl get pods -o wide`.

#### `watch-engines`

-   **Beschreibung**: Überwacht die Longhorn Engine-Pods.
-   **Ablauf**: Führt `watch kubectl -n $(NAMESPACE) get engine` aus.

#### `watch-managers`

-   **Beschreibung**: Überwacht die Longhorn Manager-Pods.
-   **Ablauf**: Führt `watch kubectl -n $(NAMESPACE) get pods | grep longhorn-manager` aus.
