

# Goal

1) Review-PR => we are reviewing the PR

The goal of this activity, or of this work that we are going to do together, is to review and redesign our skills for work with PRs. I identified two skills that I need and again I am open to discussion and suggestions.

I want to have a skill that will review a PR for me. We currently have a skill for `review-pr` here in this repo in the `.agent` folder under skills and I want you to review it. You don't have to follow it. You can suggest changes and you can take some inspiration but I'm going to express my thoughts regarding this PR.

This PR serves a purpose when I want to review someone else's PR. Someone else creates a PR and I want us to review it. For example I will give you some PR that we've already reviewed and we are going to take a look at that one so you understand. You can read through what was okay and what was not okay. I'm giving you the link to the reviewed PR.

In our repo we are working with Full Send. This is the name of the product, Full Send, and you can check its source code. You have a path to it so you can understand, in the PR, when you will see a lot of Full Send AI coder, Full Send AR AI review, and Full Send AI fix or something like that. We need to work with it. We need to be in line with it. We need to understand how it works and how to set it up. We need to also understand how to correctly use labels in this PR and how to correctly comment on the PR so we can trigger him at the correct time and stuff like that.

We need to think about it. We need to make sure that we understand how it works with it so we can then correctly set up the process and the scale of the review PR. This is the first goal that I have right now for us: to define this review PR in the sense that we are reviewing the PR. We need to review it. I would like to ask or have the scale generate HTML output so the user can take a look at what the review is about before anything is pushed to the PR. When the user approves it, then we should add the comments to the PR, right? Again the comments should have some kind of a defined form so they should follow the same kind of format as the skill already describes. I hope it is mentioned here. I just want to find it. Conventional command: that's the format that we should follow.

We should properly describe in the skill how to do it and we should also trigger a full send so he will fix our comments. Once he is done, we might run the review PR again. It should take the latest version of the code, which is in the PR, scan through the comments, and give me another HTML file that will say, "Okay this is already fixed, this is still not fixed, and these are the suggestions that I have now." We should be able to run this repeatedly on the same PR. Also take and learn the labels that we are using in the project so we know what labels we should have when we set it up. For example the original scale works with the label `full-send-no-fix`. Again we should understand that if we set it up at the end of the review, we should unset it and stuff like that. This is the first skill. 


2) Create-PR => Let's create a new PR from a worktree

The second skill that I need is Create PR. You can take inspiration from the existing skill `pull-request` that we have in this repo but we can enhance it. Again based on your findings (how the `pull` subcommand works, what the labels are there, and stuff like that), you can suggest an implementation of a Create PR skill.


3) Update-PR => We are taking care of our PR

The third skill that I need is what I call "Update PR" and you can choose a different name. It's fine with me. You don't need to follow the same naming as I said.
The ultimate goal of this is that we are taking care of our own PR. The skill should resolve the situation when I created a PR via the preview skill, created the PR, and the full send reviewed it or someone else reviewed it and we got some comments. In that moment again we need to react to it and I would like to run just this skill to give you the number or ID of the PR.
The skill should:
- Scan the comments, judge their validity, judge their importance, and add a command to the command.
- In all cases if it is a valid command, "Okay yeah, that makes sense. That would be the text of the command."
- If it is not valid, write down why it's not valid.
- In all cases resolve the conversation because usually the comments will be from the full send so we just need to add a comment, resolve the conversation, and make the changes for the relevant comments.
- Push the changes to the PR.
Again we need to understand how the PR should be treated. We need to understand the labels that the PR should have so we will correctly set these labels and we should also understand how the full send works. If we are going to add the changes, I think it will automatically trigger the full send review again.
We need to not only satisfy the commands and push the code but also orchestrate in what situations we should correctly ask Fullsend for a review, if we should. It's up to us because we can choose a model or a process where Fullsend will automatically review the PR after we have created it via the create PR skill and then turn it off. Then we can satisfy the comments, push the changes, and that's it.
We are ready for a merge from some human or we will say, "Okay we are going to let Fullstack review our PR twice: first when we push it, then we will satisfy the comments, and then he will review it again, and then we will satisfy the comments, and then we will turn it off. The human can take a look."
We need to think about this and set up the process in a way that makes sense because I don't want to be in an infinite loop with Fullsend. Each hour, a change will trigger a new review and you can always find something in the PR, not some nitpicking stuff and stuff like that. I don't want to waste the money triggering Fullsend unnecessarily. We are also triggering code a bit.
We should think about this flow from the perspective that we need to orchestrate Fullsend as well. I think that applies to the create PR also. In all three skills it's not just about us. It is also about how we should orchestrate the full stack and how we should manage the full stack. This is the third skill that I need.



## Already reviewed PR

Reviewed PR: https://github.com/redhat-et/ProtoBot/pull/61


## Fullsend 

Source code: /Users/lukaskellerstein/Projects/Github/redhat/fullsend-ai

Documentation (READ THIS): /Users/lukaskellerstein/Projects/Github/lukaskellerstein/ProtoBot/lukas/fullsend-setup





