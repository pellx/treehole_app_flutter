import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
    CreateDateColumn,
    ManyToOne,
    OneToMany,
    JoinColumn
} from 'typeorm';
import { PostEntity } from './post.entity';

@Entity('comments')
export class CommentEntity {
    @PrimaryGeneratedColumn({ comment: '唯一主键ID' })
    id: number;

    @Column({ comment: '所属贴ID' })
    post_id: number;

    @Column({ nullable: true, comment: '如果子评论，其父评论ID' })
    to_id: number;

    @Column({ default: 0, comment: '二次回复次数' })
    reply_times: number;

    @Column({ length: 100, nullable: true, comment: '用户名' })
    author: string;

    @Column({ type: 'varchar', length: 64, nullable: true, default: null, comment: '用户 token' })
    author_token: string;

    @Column({ length: 511, comment: '内容' })
    content: string;

    @CreateDateColumn({ type: 'timestamp', nullable: true, default: () => 'CURRENT_TIMESTAMP', comment: '创建时间' })
    created_at: Date;

    //relation
    @ManyToOne(() => PostEntity, (post) => post.comments, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'post_id' })
    post: PostEntity;

    @ManyToOne(() => CommentEntity, (comment) => comment.replies, { onDelete: 'CASCADE' })
    @JoinColumn({ name: 'to_id' })
    parentComment: CommentEntity;

    @OneToMany(() => CommentEntity, (comment) => comment.parentComment)
    replies: CommentEntity[];
}
