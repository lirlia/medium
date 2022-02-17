.PHONY: post
post: ## medium に post します (make post DIR=article/20220217-0)
	gh workflow run post-medium -F article_path=$(DIR)
