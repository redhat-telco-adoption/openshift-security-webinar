# Pre-Demo Checklist

Use this checklist to ensure everything is ready before your live presentation.

## 24 Hours Before Demo

### Environment Validation
- [ ] Run test suite: `./scripts/test-demo.sh`
- [ ] Verify all tests pass (0 failures)
- [ ] Check cluster has sufficient resources
  ```bash
  oc get nodes
  oc describe nodes | grep -A 5 "Allocated resources"
  ```
- [ ] Verify ACM is accessible (or plan to skip Section 6)
  ```bash
  oc get crd policies.policy.open-cluster-management.io
  ```

### Documentation Review
- [ ] Read through `docs/presentation-script.md`
- [ ] Review Q&A section for common questions
- [ ] Familiarize yourself with emergency scenarios
- [ ] Bookmark cluster inspection report

### Technical Preparation
- [ ] Test all commands in a clean namespace
- [ ] Verify error messages match expectations
- [ ] Practice the 5 failure scenarios
- [ ] Time yourself (should be 40-45 minutes)

### Equipment Check
- [ ] Test screen sharing/projection
- [ ] Verify terminal font size is readable
- [ ] Check microphone audio quality
- [ ] Prepare backup internet connection (mobile hotspot)

---

## 1 Hour Before Demo

### Cluster Setup
- [ ] Log in to OpenShift cluster
  ```bash
  oc login --server=<cluster-url> --token=<token>
  oc whoami  # Verify logged in as admin
  ```

- [ ] Deploy demo environment
  ```bash
  ./scripts/setup-demo.sh
  ```

- [ ] Verify deployment
  ```bash
  oc get all -n security-demo
  oc get pods -n security-demo  # Should show 2/2 ready
  ```

- [ ] Pre-deploy test pods (saves time in Section 4)
  ```bash
  oc create namespace test-namespace
  oc run test-pod --image=registry.access.redhat.com/ubi9/ubi-minimal:latest \
    -n test-namespace -- sleep infinity
  oc wait --for=condition=ready pod/test-pod -n test-namespace --timeout=60s
  ```

### Application Setup
- [ ] Open necessary applications:
  - [ ] Terminal (full screen)
  - [ ] Browser with OpenShift console (optional)
  - [ ] Presentation script on second monitor/tablet
  - [ ] Timer/clock visible

- [ ] Close unnecessary applications
- [ ] Disable notifications:
  - [ ] macOS: System Preferences → Notifications → Do Not Disturb
  - [ ] Windows: Settings → System → Focus Assist → Priority only
  - [ ] Linux: Disable notification daemon

- [ ] Clear browser history/cache (if showing console)

### Terminal Configuration
- [ ] Increase font size (Cmd/Ctrl + until readable)
  ```bash
  # Recommended: 18-20pt for projection
  ```

- [ ] Set terminal colors (dark background, light text)
- [ ] Clear terminal history
  ```bash
  clear
  history -c  # Optional: clear command history
  ```

- [ ] Set up multiple terminal tabs/windows (optional):
  - Tab 1: Main demo commands
  - Tab 2: Monitoring (`watch oc get pods -n security-demo`)
  - Tab 3: Backup/emergency commands

### Final Technical Checks
- [ ] Verify secure-app is running
  ```bash
  oc get deployment secure-app -n security-demo
  oc logs -l app=secure-app -n security-demo --tail=5
  ```

- [ ] Check network policies are active
  ```bash
  oc get networkpolicies -n security-demo
  ```

- [ ] Verify SCC exists
  ```bash
  oc get scc demo-restricted-scc
  ```

- [ ] Test one failure scenario
  ```bash
  oc apply -f applications/insecure-examples/privileged-pod.yaml --dry-run=server
  # Should show: Error or Warning about violations
  ```

---

## 15 Minutes Before Demo

### Environment Prep
- [ ] Position laptop/screen for comfortable viewing
- [ ] Connect to projector/screen sharing
- [ ] Test audio/microphone one more time
- [ ] Have water nearby (you'll be talking for 45 minutes!)

### Mental Preparation
- [ ] Review opening statement
- [ ] Review defense-in-depth summary table
- [ ] Take 3 deep breaths
- [ ] Remember: You know this material!

### Quick Verification
```bash
# Run these commands to verify everything is ready
oc whoami                           # Logged in
oc get ns security-demo             # Namespace exists
oc get pods -n security-demo        # Apps running (2/2)
oc get networkpolicies -n security-demo  # Policies active
```

Expected output:
```
admin
NAME            STATUS   AGE
security-demo   Active   1h

NAME                         READY   STATUS    RESTARTS   AGE
secure-app-xxxxxxxxx-xxxxx   1/1     Running   0          1h
secure-app-xxxxxxxxx-xxxxx   1/1     Running   0          1h

NAME                     POD-SELECTOR   AGE
allow-same-namespace     <none>         1h
deny-all-ingress         <none>         1h
```

---

## Immediately Before Demo (5 min)

### Final Setup
- [ ] Set terminal to full screen
- [ ] Open presentation script on second device
- [ ] Start timer (optional)
- [ ] Close all other applications
- [ ] Turn off phone or set to airplane mode

### Quick Test
- [ ] Type first command (don't execute):
  ```bash
  oc get namespace security-demo -o yaml | grep -A 5 labels
  ```
- [ ] Verify terminal is responsive
- [ ] Check screen sharing is active

### Opening Position
- [ ] Terminal showing clean prompt
- [ ] Font size verified readable
- [ ] Cursor visible
- [ ] Ready to begin!

---

## During Demo - Quick Reference

### Section Order (with timing)
1. **Introduction** (2-3 min) - Set expectations
2. **Pod Security Standards** (8 min) - 2 failures
3. **Security Context Constraints** (7 min) - 2 failures
4. **Network Policies** (8 min) - 1 failure + 1 success
5. **RBAC** (5 min) - Access control
6. **ACM Governance** (8 min) - Multi-cluster
7. **Secure vs Insecure** (5 min) - Comparison
8. **Defense-in-Depth Summary** (3 min) - Recap
9. **Conclusion** (2-3 min) - Call to action

### Key Commands Reference

**Show namespace PSS:**
```bash
oc get namespace security-demo -o yaml | grep -A 5 labels
```

**Test privileged pod:**
```bash
oc apply -f applications/insecure-examples/privileged-pod.yaml
```

**Test network policy:**
```bash
oc exec test-pod -n test-namespace -- curl -m 5 http://secure-app.security-demo.svc.cluster.local:8080
```

**Show secure app:**
```bash
oc get deployment secure-app -n security-demo -o yaml | grep -A 30 securityContext
```

---

## Emergency Procedures

### If Command Fails
1. Don't panic - take a breath
2. Say: "Let me check what's happening here..."
3. Run: `oc get events -n security-demo --sort-by='.lastTimestamp' | head -10`
4. If still stuck: "The key point is [restate the principle]"
5. Move to next section

### If Cluster Becomes Unavailable
1. Say: "We're experiencing connectivity issues"
2. Show expected output from presentation script
3. Continue narrating what would happen
4. Use the time to dive deeper into Q&A

### If Demo Runs Long
- Skip or shorten RBAC section (5 min)
- Combine sections 7 & 8 (save 3 min)
- Reduce ACM section (save 3 min)
- Always keep conclusion (call to action is important)

### If Demo Runs Short
- Expand Q&A section
- Show OpenShift web console
- Demonstrate additional failure scenarios
- Show cluster inspection report

---

## Post-Demo Actions

### Immediate (in presentation)
- [ ] Ask for questions
- [ ] Share repository URL
- [ ] Provide contact information
- [ ] Thank attendees

### Within 1 Hour
- [ ] Send follow-up email with:
  - [ ] Repository link
  - [ ] Presentation slides (if any)
  - [ ] Additional resources
  - [ ] Contact for follow-up questions

### Optional Cleanup
```bash
# If needed, remove demo environment
./scripts/cleanup-demo.sh

# Verify cleanup
oc get namespace security-demo  # Should show NotFound
```

---

## Quick Troubleshooting

### Pods Not Ready
```bash
oc describe pod <pod-name> -n security-demo
oc get events -n security-demo | grep Warning
```

### Network Policy Not Working
```bash
oc get networkpolicies -n security-demo
oc describe networkpolicy deny-all-ingress -n security-demo
```

### SCC Not Applied
```bash
oc get scc demo-restricted-scc
oc describe scc demo-restricted-scc
```

### ACM Policies Not Found
```bash
oc get crd | grep policy
oc get policies -A
# If no ACM: Skip Section 6, mention it's optional
```

---

## Success Indicators

During the demo, look for these positive signs:

✅ **Audience Engagement:**
- Taking notes
- Nodding during key points
- Leaning forward during failure demonstrations
- Questions during Q&A

✅ **Technical Success:**
- All security violations are blocked
- Error messages are clear
- Secure app runs successfully
- No unexpected issues

✅ **Message Delivery:**
- Defense-in-depth concept understood
- Attendees see value in multiple layers
- Clear takeaways about security enforcement
- Interest in implementing similar controls

---

## Confidence Boosters

**Remember:**
- ✓ You have practiced this demo
- ✓ All configurations are tested and work
- ✓ You have backup plans for issues
- ✓ The content is valuable and accurate
- ✓ You are well-prepared

**You've got this! 🎯**

---

**Last Updated:** October 29, 2025
**Version:** 1.0
