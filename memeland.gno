package memeland

import (
	"std"
	"strconv"
	"strings"
	"time"
	"sort"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/seqid"
	"gno.land/p/demo/ufmt"
)

type Post struct {
	ID            string
	Data          string
	Author        std.Address
	Timestamp     time.Time
	UpvoteTracker *avl.Tree // address > struct{}{}
}

type Memeland struct {
	Posts       []*Post
	MemeCounter seqid.ID
}

// NewMemeland returns a pointer to a new Memeland object
// Initializes all the subfields
func NewMemeland() *Memeland {
	return &Memeland{
		Posts:       make([]*Post, 0),
		MemeCounter: 0,
	}
	panic("implement me")
}

// PostMeme - Adds a new post at timestamp, with data
// Panics in case data is empty or timestamp is invalid
// Returns the ID of the created Post
func (m *Memeland) PostMeme(data string, timestamp int64) string {
	if data == "" || timestamp <= 0 {
		panic("invalid data or timestamp")
	}
	id := m.MemeCounter.Next().String()
	athAddr := std.PrevRealm().Addr()

	newPost := Post{
		ID:            id,
		Data:          data,
		Author: athAddr,
		Timestamp:     time.Unix(timestamp, 0),
		UpvoteTracker: avl.NewTree(),
	}

	m.Posts = append(m.Posts, &newPost)

	return id
}

// Upvote increases the upvote count of a specific Post
// Panics if specified ID doesn't exist, or the user has already upvoted
func (m *Memeland) Upvote(id string) string {
	for _, post := range m.Posts {
		if post.ID == id {
			// Check if the user has already upvoted
			if _, ok := post.UpvoteTracker.Get(std.PrevRealm().Addr().String()); ok {
				panic("user has already upvoted")
			}

			post.UpvoteTracker.Set(std.PrevRealm().Addr().String(), struct{}{})
			return "upvote successful"
		}
	}
	panic("id not found")
}

// GetPostsInRange returns a JSON object containing marshalled Posts in a specific timestamp range
// Timestamps are given as Unix seconds
// Supports pagination
// sortBy can be "UPVOTES" (most upvotes-first), or "DATE_CREATED" (newest-first)
// Panics if page < 1, pageSize < 1, or pageSize > 10
// Returns empty JSON object if there are no posts in the specified range.
func (m *Memeland) GetPostsInRange(startTimestamp, endTimestamp int64, page, pageSize int, sortBy string) string {
	if page < 1 || pageSize < 1 || pageSize > 10 {
		panic("invalid page or pageSize")
	}

	startIndex := (page - 1) * pageSize
	endIndex := startIndex + pageSize

	postsInRange := make([]*Post, 0)
	for _, post := range m.Posts {
		if post.Timestamp.Unix() >= startTimestamp && post.Timestamp.Unix() <= endTimestamp {
			postsInRange = append(postsInRange, post)
		}
	}

	if len(postsInRange) == 0 || startIndex >= len(postsInRange){
		return "[]"
	}

	switch sortBy {
	case "UPVOTES":
		upvoteSort(postsInRange)
	case "DATE_CREATED":
		timestampSort(postsInRange)
	default:
		panic("invalid sortBy")
	}

	if endIndex > len(postsInRange) {
		endIndex = len(postsInRange)
	}

	return PostsToJSONString(postsInRange[startIndex:endIndex])
}

// getPost gets a post by ID
func (m *Memeland) getPost(id string) *Post {
	// panic(len(m.Posts))
	for i, post := range m.Posts {
		if post.ID == id {
			return post
		}
	}
	return nil
}

// PostsToJSONString converts a slice of Post structs into a JSON string
func PostsToJSONString(posts []*Post) string {
	var sb strings.Builder
	sb.WriteString("[")

	for i, post := range posts {
		if i > 0 {
			sb.WriteString(",")
		}

		sb.WriteString(PostToJSONString(post))
	}
	sb.WriteString("]")

	return sb.String()
}

// PostToJSONString returns a Post formatted as a JSON string
// Note: Gno currently does not support reflection, which is why JSON marshalling is unavailable
func PostToJSONString(post *Post) string {
	var sb strings.Builder

	sb.WriteString("{")
	sb.WriteString(`"id":"` + post.ID + `",`)
	sb.WriteString(`"data":"` + escapeString(post.Data) + `",`)
	sb.WriteString(`"author":"` + escapeString(post.Author.String()) + `",`)
	sb.WriteString(`"timestamp":"` + strconv.Itoa(int(post.Timestamp.Unix())) + `",`)
	sb.WriteString(`"upvotes":` + strconv.Itoa(post.UpvoteTracker.Size()))
	sb.WriteString("}")

	return sb.String()
}

// escapeString escapes quotes in a string for JSON compatibility.
func escapeString(s string) string {
	return strings.ReplaceAll(s, `"`, `\"`)
}

func upvoteSort(posts []*Post) {
    n := len(posts)
    for i := 0; i < n; i++ {
        for j := 0; j < n-i-1; j++ {
            if posts[j].UpvoteTracker.Size() < posts[j+1].UpvoteTracker.Size() {
                posts[j], posts[j+1] = posts[j+1], posts[j]
            }
        }
    }
}

func timestampSort(posts []*Post) {
    n := len(posts)
    for i := 0; i < n; i++ {
        for j := 0; j < n-i-1; j++ {
            if posts[j].Timestamp.Unix() < posts[j+1].Timestamp.Unix() {
                posts[j], posts[j+1] = posts[j+1], posts[j]
            }
        }
    }
}